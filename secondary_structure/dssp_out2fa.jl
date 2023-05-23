using ArgParse
using ProgressBars
using DelimitedFiles
using DataFrames
using FASTX
using BioSequences
using BioStructures

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Directory with clusters containing DSSP assignments"
            required = true
        "--extension", "-e"
            help = "DSSP output files' extension. Default .mmcif"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

function parse_dssp_mmcif(results_path, chain)
    mmcif_dict = MMCIFDict(results_path)
    dssp_data = "_struct_conf"
    dssp_mmcif_header = ["conf_type_id", "id",
        "beg_label_comp_id", "beg_label_asym_id", "beg_label_seq_id",
        "end_label_comp_id", "end_label_asym_id", "end_label_seq_id"]
    dssp_readable_header = ["2dstruc", "2dstruc_id",
        "aa_start", "chain_start", "seq_start",
        "aa_end", "chain_end", "seq_end"]
    column_headers = string.(dssp_data, ".", dssp_mmcif_header)
    assignments = Matrix{Any}(undef, length(mmcif_dict[first(column_headers)]), length(column_headers))
    for (i, header) in enumerate(column_headers)
        assignments[:, i] = mmcif_dict[header]
    end
    #Obtain sequence
    struc = ProteinStructure(mmcif_dict)
    sequence = LongAminoAcidSeq(struc[chain], standardselector, gaps=true)
    df = DataFrame(assignments, dssp_readable_header)
    filter!(:chain_end => ==(chain), df)
    df.seq_start = parse.(Int64, df.seq_start)
    df.seq_end = parse.(Int64, df.seq_end)
    return (df, sequence)
end

function fix_isolated_bridge(str)
    assignment = str
    for i in eachindex(str)
        if str[i] == 'E'
            isolated = 2
            try
                if str[i-1] !== 'E'
                    isolated -= 1
                end
            catch e
                nothing
            end
            try
                if str[i+1] !== 'E'
                    isolated -= 1
                end
            catch e
                nothing
            end
            if isolated == 0
                assignment = str_sub(assignment, 'B', i, i)
            end
        end
    end
    return assignment
end

function str_sub(str::String, replacement::Char, istart::Int, iend::Int)
    change = repeat(replacement, iend - istart + 1)
    return SubString(str, firstindex(str), istart-1) * change * SubString(str, iend+1, lastindex(str))
end

function normalize_dssp_ouput(df, seq_len)
    assignment = repeat('C', seq_len)
    dssp_dict = Dict("HELX_LH_PP_P" => 'C', #Ignore for now (No equivalent in Q8)
                    "HELX_RH_AL_P" => 'H',
                    "STRN" => 'E', #Almost never B (isolated beta-bridge)
                    "HELX_RH_3T_P" => 'G',
                    "HELX_RH_PI_P" => 'I',
                    "TURN_TY1_P" => 'T',
                    "BEND" => 'S')
    for row in eachrow(df)
        assignment = str_sub(assignment, dssp_dict[row["2dstruc"]], row["seq_start"], row["seq_end"])
    end
    #Change E to B if isolated (Must make sure it makes sense)
    assignment = fix_isolated_bridge(assignment)
    return assignment
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if isnothing(parsed_args["extension"])
    parsed_args["extension"] = ".mmcif"
end

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if endswith(f, parsed_args["extension"])
            f_path = joinpath(root,f)
            f_noext = splitext(f)[1]
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_path = joinpath(f_out_dir, "$(f_noext).ssfa")
            if !isfile(f_out_path)
                try
                    sequence_file = joinpath(root, "$(f_noext).fa")
                    chain = last(split(f_noext, '_'))
                    mkpath(f_out_dir)
                    assign_df, assign_seq = parse_dssp_mmcif(f_path, chain)
                    assignment = normalize_dssp_ouput(assign_df, length(assign_seq))
                    #Write assignment to .ssfa
                    FASTA.Writer(open(f_out_path, "w")) do writer
                        write(writer, FASTA.Record("dssp_$(f_noext)", LongCharSeq(assignment)))
                    end
                catch e
                    println("Error on $(f_path)")
                    continue
                end
            end
        end
    end
end