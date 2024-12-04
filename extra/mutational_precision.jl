using ArgParse
using DelimitedFiles, DataFrames
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with protein ss fasta files required"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--consensus", "-c"
            help = "Consensus file basename"
            default = "consensus.txt"
        "--methods", "-m"
            help = "List (Separation symbol: +) of methods to be analyzed."
            required = true
        "--metrics_calculator", "-t"
            help = "Path to metrics calculator tool. Usually ssmetrics executable or SOV_refine.pl script"
            required = true
    end
    return parse_args(s)
end

input_conditions(a,f) = return basename(f) == a["consensus"]

function initialize!(args, var)
    var["fext"] = ".res"
    var["refext"] = ".ssfa"
    var["predext"] = ".sspfa"
    var["metrics"] = ["Accuracy", "SOV_99", "SOV_refine"]
    log_initialize!(args, var)
end

function preprocess!(args, var) 
    input_dir_out_preprocess!(var, "mutation_precision"; fext=var["fext"])
end

function compare_consensus_mutated(consensus_ss8, mutated_ss8)
    comparison = ""
    for i in eachindex(consensus_ss8)
        comparison *= consensus_ss8[i]
        comparison *= mutated_ss8[i]
    end
    return comparison
end

function commands(args, var)
    cluster = basename(var["abs_input_dir"])
    consensus_df = read_consensus(var["input_path"])
    consensus_protein = get_consensus(consensus_df)
    consensus_ref_file = joinpath(var["abs_input_dir"], "$consensus_protein$(var["refext"])")
    consensus_ref_ss8 = read_fasta(consensus_ref_file)
    mutated_proteins = get_mutations(consensus_df)
    mutated_ref_files = Dict()
    for mutated_protein in mutated_proteins
        mutated_ref_files[mutated_protein] = joinpath(var["abs_input_dir"], "$mutated_protein$(var["refext"])")
    end
    consensus_pred_files = Dict()
    mutated_pred_files = Dict()
    for method in prediction_methods_from_string(args["methods"])
        consensus_pred_files[method] = joinpath(var["abs_input_dir"], method, "$consensus_protein$(var["predext"])")
        for mutated_protein in mutated_proteins
            if !haskey(mutated_pred_files, method)
                mutated_pred_files[method] = Dict(mutated_protein => joinpath(var["abs_input_dir"], method, "$mutated_protein$(var["predext"])"))
            else
                mutated_pred_files[method][mutated_protein] = joinpath(var["abs_input_dir"], method, "$mutated_protein$(var["predext"])")
            end
        end
    end
    for mutated_protein in mutated_proteins
        mutated_ref_ss8 = read_fasta(mutated_ref_files[mutated_protein])
        ref_comparison = compare_consensus_mutated(sequence(consensus_ref_ss8), sequence(mutated_ref_ss8))
        for method in prediction_methods_from_string(args["methods"])
            consensus_pred_ss8 = read_fasta(consensus_pred_files[method])
            mutated_pred_ss8 = read_fasta(mutated_pred_files[method][mutated_protein])
            pred_comparison = compare_consensus_mutated(sequence(consensus_pred_ss8), sequence(mutated_pred_ss8))
            ref_comparison_file = write_temp("reference", ref_comparison)
            pred_comparison_file = write_temp("prediction", pred_comparison)
            precision_metrics = get_metrics(args["metrics_calculator"], var["metrics"], ref_comparison_file, pred_comparison_file)
            write_file(var["output_file"], "$cluster $consensus_protein $mutated_protein $method $(precision_metrics["Accuracy"]) $(precision_metrics["SOV_99"]) $(precision_metrics["SOV_refine"])")
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()