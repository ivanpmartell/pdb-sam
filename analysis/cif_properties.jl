using ArgParse
using BioStructures
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--overwrite", "-w"
            help = "Overwrite previous output"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with secondary structure assignment files required"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--extension", "-e"
            help = "Secondary structure assignment file extension"
            default = ".mmcif"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(parent_dir(f), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "protein_properties"; fext=".txt")
end

function multisplit(str::String, v::Vector{String})
    split_result = strip.(split(str, v[1], keepempty=false))
    for split_str in v[2:end]
        split_len = length(split_result)
        cur_split_result = []
        for i in 1:split_len
            append!(cur_split_result, strip.(split(split_result[i], split_str, keepempty=false)))
        end
        split_result = cur_split_result
    end
    return split_result
end

function get_descriptions(in_path)
    mmcif_dict = MMCIFDict(in_path)
    reference = "_struct_keywords"
    uniprot_data_header = ["text", "pdbx_keywords"]
    column_headers = string.(reference, ".", uniprot_data_header)
    descriptions = Set{String}()
    for col in column_headers
        val = uppercase(first(mmcif_dict[col]))
        val_split = multisplit(val, [",", "(", ")", "- ", " -", " /", "/ "])
        for v in val_split
            clean = strip(v,['/', '-'])
            if length(clean) > 2
                push!(descriptions, clean)
            end
        end
    end
    return descriptions
end

function commands(args, var)
    protein = var["input_noext"]
    descriptions = get_descriptions(var["input_path"])
    for desc in descriptions
        write_file(var["output_file"], "$protein $desc")
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!, overwrite=parsed_args["overwrite"])
    return 0
end

main()