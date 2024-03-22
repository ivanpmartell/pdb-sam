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

input_conditions(a,f) = return startswith(basename(f), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "uniprot_ids"; fext=".txt", cdir=var["input_basename"])
end

function get_uniprot_id(in_path)
    mmcif_dict = MMCIFDict(in_path)
    reference = "_struct_ref"
    uniprot_data_header = ["db_name", "db_code", "pdbx_db_accession"]
    column_headers = string.(reference, ".", uniprot_data_header)
    for (i, ref) in enumerate(mmcif_dict[first(column_headers)])
        if lowercase(ref) == "unp"
            accession_header = last(column_headers)
            return uppercase(mmcif_dict[accession_header][i])
        end
    end
end

function commands(args, var)
    for prot in process_input(var["input_path"], 'f'; input_conditions=(a,x)->has_extension(x, args["extension"]), silence=true)
        mmcif_path = joinpath(var["input_path"], prot)
        pdb = remove_ext(basename(prot))
        uniprot = get_uniprot_id(mmcif_path)
        write_file(var["output_file"], "$pdb $uniprot")
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()