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
        "--data_dir", "-d"
            help = "Directory containing alphafold databases"
            required = true
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

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(last(splitdir(dirname(f))), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"], "pdb", "af2/")
end

function commands(args, var)
    mkpath(args["temp_output"])
    features_file = joinpath(args["temp_output"], "$(var["input_noext"])/features.pkl")
    if isfile("$(f_out).pkl")
        if args["msa_only"]
            return 0
        end
        mkpath(joinpath(args["temp_output"], var["input_noext"]))
        mv("$(f_out).pkl", features_file)
    end
    run(Cmd(`./run_alphafold.sh -d $(args["data_dir"]) -o $(args["temp_output"]) -p monomer_ptm -i $(var["input_path"]) -m model_1,model_2,model_3,model_4,model_5 -t 2020-05-14 $(gpu_usage) $(parafold_args)`, dir=args["parafold_dir"]))
    if args["msa_only"]
        cp(features_file, "$(var["output_file"]).pkl")
    else
        cp(joinpath(args["temp_output"], "$(var["input_noext"])/ranked_0.pdb"), f_out)
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    gpu_usage = ``
    if parsed_args["use_gpu"]
        gpu_usage = `-gG`
    end
    parafold_args = ``
    if parsed_args["msa_only"] && parsed_args["predict_only"]
        throw(ArgumentError("Choose MSA features only or Predict only. To do both, ignore both flags."))
    elseif parsed_args["msa_only"]
        parafold_args = `-f`
    elseif parsed_args["predict_only"]
        parafold_args = `-s`
    end
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()