#Use af2 conda env
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
        "--af2_dir", "-a"
            help = "Directory containing AlphaFold2 repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--use_gpu", "-g"
            help = "Use Nvidia GPU. If not selected, use CPU only"
            action = :store_true
        "--temp_output", "-t"
            help = "Temporary output directory. Usually somewhere outside your output directory"
            required = true

    end
    return parse_args(s)
end

parsed_args = parse_commandline()
gpu_usage = "--use_gpu=True"
if !parsed_args["use_gpu"]
    gpu_usage = "--use_gpu=False"
end

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && startswith(last(splitdir(in_path)), "Cluster")
end

function commands(f_path, f_noext, f_out)
    mkpath(parsed_args["temp_output"])
    af2 = joinpath(parsed_args["af2_dir"], "docker/run_docker.py")
    run(`python $(af2) --fasta_paths=$(f_path) $(gpu_usage) --max_template_date=2020-05-14 --docker_user=0`)
    mv(joinpath(parsed_args["temp_output"], "$(f_noext)/ranked_0.pdb"), f_out)
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "pdb", commands, parsed_args["skip_error"], "af2/")
