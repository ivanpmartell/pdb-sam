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
        "--spot1d_lm_dir", "-s"
            help = "Directory containing SPOT-1D-LM repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--gpu_device_esm", "-ge"
            help = "GPU device for ESM prediction"
            arg_type = Int
            default = -1
        "--gpu_device_pt", "-gp"
            help = "GPU device for ProtTrans prediction"
            arg_type = Int
            default = -1
        "--gpu_device_lm", "-g"
            help = "GPU device for SPOT1D LM prediction"
            arg_type = Int
            default = -1

    end
    return parse_args(s)
end

function create_filelist(current_file_path, filelist_path)
    abs_file_path = current_file_path
    if !startswith(current_file_path, '/')
        abs_file_path = joinpath(pwd(), current_file_path)
    end
    open(filelist_path, "w") do writer
        println(writer, abs_file_path)
    end
end

function parse_gpu(device)
    if device == -1
        return "cpu"
    else
        return "cuda:$(device)"
    end
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".csv", cdir="spot1d_lm/")
end

function commands(args, var)
    spot1d_lm_output_dir = joinpath(args["spot1d_lm_dir"], "results/")
    abs_filelist_path = abspath("tmp_s1dlm_filelist.txt")
    create_filelist(var["input_path"], abs_filelist_path)
    run(Cmd(`./run_SPOT-1D-LM.sh $(abs_filelist_path) $(parse_gpu(args["gpu_device_esm"])) $(parse_gpu(args["gpu_device_pt"])) $(parse_gpu(args["gpu_device_lm"]))`, dir=args["spot1d_lm_dir"]))
    #Move files from spot1d outputs to output folder once processed. Clean spot1d directory.
    cp(joinpath(spot1d_lm_output_dir, "$(var["input_noext"]).csv"), var["output_file"])
    rm(abs_filelist_path)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()