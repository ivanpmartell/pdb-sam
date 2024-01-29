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

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(last(splitdir(dirname(f))), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"], "pdb", "af2/")
end

function commands(args, var)
    mkpath(args["temp_output"])
    af2 = joinpath(args["af2_dir"], "docker/run_docker.py")
    run(`python $(af2) --fasta_paths=$(var["input_path"]) $(gpu_usage) --max_template_date=2020-05-14 --docker_user=0`)
    mv(joinpath(args["temp_output"], "$(var["input_noext"])/ranked_0.pdb"), var["output_file"])
end

function main()::Cint
    parsed_args = parse_commandline()
    gpu_usage = "--use_gpu=True"
    if !parsed_args["use_gpu"]
        gpu_usage = "--use_gpu=False"
    end
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()
