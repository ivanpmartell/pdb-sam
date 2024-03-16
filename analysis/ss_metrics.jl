using ArgParse
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory containing secondary structure results"
            required = true
        "--extension", "-e"
            help = "Extension for input secondary structure fasta files"
            default = ".ssfa"
        "--prediction_extension", "-x"
            help = "Extension for predicted secondary structure fasta files"
            default = ".sspfa"
        "--mutation_file", "-t"
            help = "Mutation file basename"
            default = "mutations.txt"
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--sov_refine", "-s"
            help = "Path to SOV_refine perl script to produce metrics. Usually called SOV_refine.pl"
            required = true
        "--mask", "-m"
            help = "Agglomerate mutation results within cluster. Mask and reduce irrelevant (non local) parts of sequence to produce results"
            action = :store_true
    end
    return parse_args(s)
end

input_conditions(a,f) = return startswith(basename(f), "Cluster")

function initialize!(args, var)
    log_initialize!(args, var)
    var["metrics"] = ["Accuracy", "SOV_99", "SOV_refine"]
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "vicinity"; fext=".metrics", cdir=var["input_basename"])
end

function read_metrics(var, sov_refine_output)
    results = Dict{String, Float32}()
    for line in split(sov_refine_output, '\n')
        line_split = split(line, '\t')
        if first(line_split) in var["metrics"]
            results[first(line_split)] = parse(Float32, last(line_split))
        end
    end
    return results
end

function get_vicinity_type_filename(vicinity, type)
    ext = ""
    if type == "1d"
        ext = ".1dv"
    elseif type == "2d"
        ext = ".2dv"
    elseif type == "3d"
        ext = ".3dv"
    elseif type == "contact"
        ext = ".cdv"
    else
        throw(ErrorException("Wrong type"))
    end
    return "$vicinity$ext"
end

function write_temp(name, seq)
    tmp_file = tempname()
    FASTA.Writer(open(tmp_file, "w")) do writer
        write(writer, FASTA.Record(name, seq))
    end
    return tmp_file
end

function get_metrics(args, var, file_ref, file_pred)
    cmd = pipeline(`$(args["sov_refine"]) $(file_ref) $(file_pred)`, stderr=devnull)
    output = read(cmd, String)
    return read_metrics(var, output)
end

function create_temp_files(args, indices, ref_sequence, pred_sequence, protein_name)
    tmp_ref = ""
    tmp_pred = ""
    if args["mask"]
        ref_masked = mask_non_consecutive(ref_sequence, indices)
        tmp_ref = write_temp(protein_name, ref_masked)
        pred_masked = mask_non_consecutive(pred_sequence, indices)
        tmp_pred = write_temp(protein_name, pred_masked)
    else
        tmp_ref = write_temp(protein_name, ref_sequence[indices])
        tmp_pred = write_temp(protein_name, pred_sequence[indices])
    end
    return tmp_ref, tmp_pred
end

function commands(args, var)
    mutation_file = joinpath(var["input_path"], args["mutation_file"])
    mutations = read_mutations(mutation_file)
    global_file = joinpath(var["abs_output_dir"], "global.metrics")
    mut_out_file = joinpath(var["abs_output_dir"], "mutation.metrics")
    for protein_ref in process_input(var["input_path"], 'f'; input_conditions=(a,x)->has_extension(x, args["extension"]), silence=true)
        ref_path = joinpath(var["input_path"], protein_ref)
        protein_name = first(basename_ext(protein_ref))
        ref_sequence = sequence(read_fasta(ref_path))
        for tool in get_prediction_methods()
            pred_path = joinpath(var["input_path"], tool, "$protein_name$(args["prediction_extension"])")
            pred_sequence = sequence(read_fasta(pred_path))
            #Overall Global metrics
            global_metrics = get_metrics(args, var, ref_path, pred_path)
            write_file(global_file, "$(var["input_basename"]) $protein_name $tool $(global_metrics["Accuracy"]) $(global_metrics["SOV_99"]) $(global_metrics["SOV_refine"])")
            for type in ["1d", "2d", "3d", "contact"]
                #Mutation vicinity metrics
                mutations_vicinity_file = joinpath(var["input_path"], get_vicinity_type_filename("cluster", type))
                mut_vic_indices = read_mutations_vicinity_file(mutations_vicinity_file)
                muts = mutations_in_protein(mutations, protein_name)
                for m in muts
                    mut = "$(m.from)$(m.position)$(m.to)"
                    #Local
                    mut_indices = mut_vic_indices[mut]
                    tmp_ref, tmp_pred = create_temp_files(args, mut_indices, ref_sequence, pred_sequence, protein_name)
                    metrics = get_metrics(args, var, tmp_ref, tmp_pred)
                    write_file(mut_out_file, "$(var["input_basename"]) $protein_name $mut $tool $type local $(metrics["Accuracy"]) $(metrics["SOV_99"]) $(metrics["SOV_refine"])")
                    #Non-local
                    nl_indices = collect(1:length(ref_sequence))
                    deleteat!(nl_indices, mut_indices)
                    nl_ref, nl_pred = create_temp_files(args, nl_indices, ref_sequence, pred_sequence, protein_name)
                    nl_metrics = get_metrics(args, var, nl_ref, nl_pred)
                    write_file(mut_out_file, "$(var["input_basename"]) $protein_name $mut $tool $type non_local $(nl_metrics["Accuracy"]) $(nl_metrics["SOV_99"]) $(nl_metrics["SOV_refine"])")
                    #Global
                    write_file(mut_out_file, "$(var["input_basename"]) $protein_name $mut $tool $type global $(global_metrics["Accuracy"]) $(global_metrics["SOV_99"]) $(global_metrics["SOV_refine"])")
                end
                #Overall Local vs non-local metrics
                for vicinity in ["local", "non_local"]
                    vicinity_type_file = joinpath(var["input_path"], get_vicinity_type_filename(vicinity, type))
                    indices = read_vicinity_file(vicinity_type_file)
                    tmp_ref, tmp_pred = create_temp_files(args, indices, ref_sequence, pred_sequence, protein_name)
                    metrics = get_metrics(args, var, tmp_ref, tmp_pred)
                    write_file(var["output_file"], "$(var["input_basename"]) $protein_name $tool $type $vicinity $(metrics["Accuracy"]) $(metrics["SOV_99"]) $(metrics["SOV_refine"])")
                end
            end
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()