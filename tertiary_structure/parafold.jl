#Use af2 conda env
using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--data_dir", "-d"
            help = "Directory containing alphafold databases"
            required = true #TODO: make optional by create_command separate by space and looking at last to see if empty
        "--parafold_dir", "-a"
            help = "Directory containing ParallelFold repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--use_gpu", "-g"
            help = "Use Nvidia GPU. If not selected, use CPU only"
            action = :store_true
        "--msa_only", "-f"
            help = "Calculate MSA features only"
            action = :store_true
        "--predict_only", "-p"
            help = "Neural network prediction only using precomputed MSAs"
            action = :store_true
        "--temp_output", "-t"
            help = "Temporary output directory. Usually somewhere outside your output directory"
            required = true
        "--unified_mem", "-u"
            help = "Unify RAM and GPU memory for bigger molecules that would not fit in GPU memory alone"
            action = :store_true

    end
    return parse_args(s)
end

parsed_args = parse_commandline()
gpu_usage = ""
if parsed_args["use_gpu"]
    gpu_usage = "-gG"
end
parafold_args = ""
if parsed_args["msa_only"] && parsed_args["predict_only"]
    throw(ArgumentError("Choose MSA features only or Predict only. To do both, ignore both flags."))
elseif parsed_args["msa_only"]
    parafold_args = "-P"
elseif parsed_args["predict_only"]
    parafold_args = "-s"
end

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && startswith(last(splitdir(in_path)), "Cluster") #no error file
end

function commands(f_path, f_noext, f_out)
    mkpath(parsed_args["temp_output"])
    run(Cmd(create_command("run_alphafold.sh", ["-d $(parsed_args["data_dir"])", "-o $(parsed_args["output"])", "-p monomer_ptm", "-i $(f_path)", "-m model_1,model_2,model_3,model_4,model_5", "-t 2020-05-14", gpu_usage, parafold_args]), dir=parsed_args["parafold"]))
    cp(joinpath(parsed_args["temp_output"], "$(f_noext)/ranked_0.pdb"), f_out)
end

work_on_files(parsed_args["input"], parsed_args["output"], input_conditions, "af2/", "pdb", commands, "min")
