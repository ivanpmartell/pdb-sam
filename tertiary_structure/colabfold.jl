using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-s"
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

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && startswith(last(splitdir(in_path)), "Cluster")
end

function commands(f_path, f_noext, f_out)
    mkpath(parsed_args["temp_output"])
    run(`$(parsed_args["colabfold_exe"]) --templates --amber --num-relax 1 $(f_path) $(parsed_args["temp_output"])`)
    for (root_out, dirs_out, files_out) in walkdir(parsed_args["temp_output"])
        for file_out in files_out
            if startswith(file_out, f_noext)
                if occursin("relaxed_rank_001", file_out)
                    file_out_path = joinpath(root_out, file_out)
                    mv(file_out_path, f_out)
                    break
                end
            end
        end
    end
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "pdb", commands, parsed_args["skip_error"], "colabfold/")
