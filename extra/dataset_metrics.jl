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
            help = "Input directory containing secondary structure results"
            required = true
        "--extension", "-e"
            help = "Extension for input secondary structure fasta files"
            default = ".ssfa"
        "--prediction_extension", "-x"
            help = "Extension for predicted secondary structure fasta files"
            default = ".sspfa"
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--metrics_calculator", "-m"
            help = "Path to metrics calculator tool. Usually ssmetrics executable or SOV_refine.pl script"
            required = true
        "--append", "-a"
            help = "Append new method to already existing metrics. Avoids recalculating all previous methods."
    end
    return parse_args(s)
end

input_conditions(a,f) = return startswith(basename(f), "Cluster")

function initialize!(args, var)
    log_initialize!(args, var)
    var["metrics"] = ["Accuracy", "SOV_99", "SOV_refine"]
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "dataset"; fext=".metrics", cdir=var["input_basename"])
end

function commands(args, var)
    tools = get_prediction_methods()
    if args["append"] !== nothing
        tools = prediction_methods_from_string(args["append"])
    end
    for protein_ref in process_input(var["input_path"], 'f'; input_conditions=(a,x)->has_extension(x, args["extension"]), silence=true)
        ref_path = joinpath(var["input_path"], protein_ref)
        protein_name = first(basename_ext(protein_ref))
        if isfile(ref_path)
            for tool in tools
                pred_path = joinpath(var["input_path"], tool, "$protein_name$(args["prediction_extension"])")
                if isfile(pred_path)
                    database_metrics = get_metrics(args["metrics_calculator"], var["metrics"], ref_path, pred_path)
                    write_file(var["output_file"], "$(var["input_basename"]) $protein_name $tool $(database_metrics["Accuracy"]) $(database_metrics["SOV_99"]) $(database_metrics["SOV_refine"])")
                end
            end
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    overwrite_file = parsed_args["append"] !== nothing
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!, overwrite=overwrite_file)
    return 0
end

main()