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
    input_dir_out_preprocess!(var, "rgn2_fix_vicinity"; fext=".metrics", cdir=var["input_basename"])
end

function write_global_metrics(args, var, protein_name, global_metrics, out_file)
    write_file(out_file, "$(var["input_basename"]) $protein_name $(global_metrics["Accuracy"]) $(global_metrics["SOV_99"]) $(global_metrics["SOV_refine"])")
end

function write_mutations_metrics(args, var, indices, ref_seq, pred_seq, protein_name, mut, type, vicinity, out_file)
    tmp_ref, tmp_pred = create_temp_files(args["mask"], indices, ref_seq, pred_seq, protein_name)
    metrics = get_metrics(args["sov_refine"], var["metrics"], tmp_ref, tmp_pred)
    write_file(out_file, "$(var["input_basename"]) $protein_name $mut $type $vicinity $(metrics["Accuracy"]) $(metrics["SOV_99"]) $(metrics["SOV_refine"])")
end

function write_vicinity_metrics(args, var, indices, ref_seq, pred_seq, protein_name, type, vicinity, out_file)
    tmp_ref, tmp_pred = create_temp_files(args["mask"], indices, ref_seq, pred_seq, protein_name)
    metrics = get_metrics(args["sov_refine"], var["metrics"], tmp_ref, tmp_pred)
    write_file(out_file, "$(var["input_basename"]) $protein_name $type $vicinity $(metrics["Accuracy"]) $(metrics["SOV_99"]) $(metrics["SOV_refine"])")
end

function remove_fixed_indices!(indices, seq_length)
    for i in seq_length+1:seq_length+2
        loc = searchsorted(indices, i)
        if !isempty(loc)
            deleteat!(indices, loc)
        end
    end
end

function commands(args, var)
    mutation_file = joinpath(var["input_path"], args["mutation_file"])
    mutations = read_mutations(mutation_file)
    fix_global_file = joinpath(var["abs_output_dir"], "rgn2_fix_global.metrics")
    nofix_global_file = joinpath(var["abs_output_dir"], "rgn2_nofix_global.metrics")
    fix_mut_out_file = joinpath(var["abs_output_dir"], "rgn2_fix_mutation.metrics")
    nofix_mut_out_file = joinpath(var["abs_output_dir"], "rgn2_nofix_mutation.metrics")
    nofix_vic_out_file = joinpath(var["abs_output_dir"], "rgn2_nofix_vicinity.metrics")
    for protein_pred in process_input(var["input_path"], 'f'; input_conditions=(a,x)->has_extension(x, args["prediction_extension"]) && parent_dir(x) == "rgn2", nested=true, silence=true)
        pred_path = joinpath(var["input_path"], protein_pred)
        protein_name = first(basename_ext(protein_pred))
        pred_sequence = sequence(read_fasta(pred_path))
        pred_sequence_original = pred_sequence[1:end-2]
        original_sequence_length = length(pred_sequence_original)
        ref_path = joinpath(var["input_path"], "$protein_name$(args["extension"])")
        ref_sequence = sequence(read_fasta(ref_path))
        ref_sequence_original = ref_sequence[1:end-2]
        #Global metrics
        fix_global_metrics = get_metrics(args["sov_refine"], var["metrics"], ref_path, pred_path)
        write_global_metrics(args, var, protein_name, fix_global_metrics, fix_global_file)
        global_ref, global_pred = create_temp_files(args["mask"], :, ref_sequence_original, pred_sequence_original, protein_name)
        nofix_global_metrics = get_metrics(args["sov_refine"], var["metrics"], global_ref, global_pred)
        write_global_metrics(args, var, protein_name, nofix_global_metrics, nofix_global_file)
        for type in ["1d", "2d", "3d", "contact"]
            #Mutation vicinity metrics
            mutations_vicinity_file = joinpath(var["input_path"], get_vicinity_type_filename("cluster", type))
            mut_vic_indices = read_mutations_vicinity_file(mutations_vicinity_file)
            muts = mutations_in_protein(mutations, protein_name)
            for m in muts
                mut = "$(m.from)$(m.position)$(m.to)"
                #Local
                fix_mut_indices = mut_vic_indices[mut]
                nofix_mut_indices = deepcopy(fix_mut_indices)
                remove_fixed_indices!(nofix_mut_indices, original_sequence_length)
                write_mutations_metrics(args, var, fix_mut_indices, ref_sequence, pred_sequence, protein_name, mut, type, "local", fix_mut_out_file)
                write_mutations_metrics(args, var, nofix_mut_indices, ref_sequence_original, pred_sequence_original, protein_name, mut, type, "local", nofix_mut_out_file)
                #Non-local
                fix_nl_indices = collect(1:length(ref_sequence))
                deleteat!(fix_nl_indices, fix_mut_indices)
                nofix_nl_indices = collect(1:length(ref_sequence_original))
                deleteat!(nofix_nl_indices, nofix_mut_indices)
                write_mutations_metrics(args, var, fix_nl_indices, ref_sequence, pred_sequence, protein_name, mut, type, "non_local", fix_mut_out_file)
                write_mutations_metrics(args, var, nofix_nl_indices, ref_sequence_original, pred_sequence_original, protein_name, mut, type, "non_local", nofix_mut_out_file)
                #Global
                write_file(fix_mut_out_file, "$(var["input_basename"]) $protein_name $mut $type global $(fix_global_metrics["Accuracy"]) $(fix_global_metrics["SOV_99"]) $(fix_global_metrics["SOV_refine"])")
                write_file(nofix_mut_out_file, "$(var["input_basename"]) $protein_name $mut $type global $(nofix_global_metrics["Accuracy"]) $(nofix_global_metrics["SOV_99"]) $(nofix_global_metrics["SOV_refine"])")
            end
            #Overall Local vs non-local metrics
            for vicinity in ["local", "non_local"]
                vicinity_type_file = joinpath(var["input_path"], get_vicinity_type_filename(vicinity, type))
                indices = read_vicinity_file(vicinity_type_file)
                write_vicinity_metrics(args, var, indices, ref_sequence, pred_sequence, protein_name, type, vicinity, var["output_file"])
                remove_fixed_indices!(indices, original_sequence_length)
                write_vicinity_metrics(args, var, indices, ref_sequence_original, pred_sequence_original, protein_name, type, vicinity, nofix_vic_out_file)
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