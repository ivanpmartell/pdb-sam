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
            help = "Input directory containing vicinity files"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
    end
    return parse_args(s)
end

input_conditions(a,f) = return startswith(basename(f), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "mut_vicinity_length"; fext=".txt", cdir=var["input_basename"])
end

function commands(args, var)
    cluster = basename(var["input_path"])
    vicinity_out = joinpath(var["abs_output_dir"], "vicinity_length.txt")
    for type in ["1d", "2d", "3d", "contact"]
        for vicinity in ["local", "non_local"]
            vicinity_type_file = joinpath(var["input_path"], get_vicinity_type_filename(vicinity, type))
            indices = read_vicinity_file(vicinity_type_file)
            write_file(vicinity_out, "$cluster $vicinity $type $(length(indices))")
        end
        mut_vicinity_file = joinpath(var["input_path"], get_vicinity_type_filename("cluster", type))
        mut_vic_indices = read_mutations_vicinity_file(mut_vicinity_file)
        for mkey in keys(mut_vic_indices)
            write_file(var["output_file"], "$mkey $type $(length(mut_vic_indices[mkey]))")
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()