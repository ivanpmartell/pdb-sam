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
        "--esmfold_exe", "-m"
            help = "ESMFold executable file. Usually esm-fold"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(last(splitdir(dirname(f))), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".pdb", cdir="esmfold/")
end

function commands(args, var)
    run(`$(args["esmfold_exe"]) -i $(var["input_path"]) -o $(var["abs_output_dir"]) --cpu-offload`) #--chunk-size 128 for longer proteins (>1000)
    for (root_out, dirs_out, files_out) in walkdir(var["abs_output_dir"])
        for file_out in files_out
            if startswith(file_out, var["input_noext"])
                file_out_path = joinpath(root_out, file_out)
                if (file_out_path != var["output_file"])
                    mv(file_out_path, var["output_file"], force=true)
                end
                break
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