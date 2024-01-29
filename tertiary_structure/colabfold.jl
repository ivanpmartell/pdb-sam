using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--colabfold_exe", "-c"
            help = "ColabFold executable file. Usually colabfold_batch"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--temp_output", "-t"
            help = "Temporary output directory. Usually somewhere outside your output directory"
            required = true

    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(last(splitdir(dirname(f))), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"], "pdb", "colabfold/")
end

function commands(args, var)
    mkpath(args["temp_output"])
    run(`$(args["colabfold_exe"]) --templates --amber --num-relax 1 $(var["input_path"]) $(args["temp_output"])`)
    for (root_out, dirs_out, files_out) in walkdir(args["temp_output"])
        for file_out in files_out
            if startswith(file_out, var["input_noext"])
                if occursin("relaxed_rank_001", file_out)
                    file_out_path = joinpath(root_out, file_out)
                    mv(file_out_path, var["output_file"])
                    break
                end
            end
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()