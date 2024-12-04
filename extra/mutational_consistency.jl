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
    end
    return parse_args(s)
end

input_conditions(a,f) = return basename(f) == a["consensus"]

function initialize!(args, var)
    var["fext"] = ".res"
    var["refext"] = ".ssfa"
    var["predext"] = ".sspfa"
    log_initialize!(args, var)
end

function preprocess!(args, var) 
    input_dir_out_preprocess!(var, "mutation_consistency"; fext=var["fext"])
end

function compare_consensus_mutated(consensus_ss8, mutated_ss8)
    comparison = ""
    for i in eachindex(consensus_ss8)
        if consensus_ss8[i] == mutated_ss8[i]
            comparison *= "N"
        else
            comparison *= "C"
        end
    end
    return comparison
end

function calculate_confusion_matrix(reference, prediction)
    total = tp = fp = tn = fn = 0
    for i in eachindex(reference)
        total += 1
        if reference[i] == 'C'
            if reference[i] == prediction[i]
                tp += 1
            else
                fp += 1
            end
        else
            if reference[i] == prediction[i]
                tn += 1
            else
                fn += 1
            end
        end
    end
    return total, tp, fp, tn, fn
end

function calculate_consistency(total, tp, tn)
    return (tp + tn) / total
end

function calculate_sensitivity(tp, fn)
    denominator = (tp + fn)
    if denominator != 0
        return tp / denominator
    else
        return 0
    end
end

function calculate_specificity(fp, tn)
    denominator = (fp + tn)
    if denominator != 0
        return tn / denominator
    else
        return 0
    end
end

function calculate_positive_predval(tp, fp)
    denominator = (tp + fp)
    if denominator != 0
        return tp / denominator
    else
        return 0
    end
end

function calculate_negative_predval(tn ,fn)
    denominator = (tn + fn)
    if denominator != 0
        return tn / denominator
    else
        return 0
    end
end

function calculate_false_positive_rate(specificity)
    return 1 - specificity
end

function calculate_false_negative_rate(sensitivity)
    return 1 - sensitivity
end

function calculate_false_omission_rate(negative_predval)
    return 1 - negative_predval
end

function calculate_false_discovery_rate(positive_predval)
    return 1 - positive_predval
end

function calculate_mcc(tpr, tnr, ppv, npv, fnr, fpr, fomir, fdisr)
    return sqrt(tpr * tnr * ppv * npv) - sqrt(fnr * fpr * fomir * fdisr)
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
            (total, tp, fp, tn, fn) = calculate_confusion_matrix(ref_comparison, pred_comparison)
            consistency = calculate_consistency(total, tp, tn)
            sensitivity = calculate_sensitivity(tp, fn)
            specificity = calculate_specificity(fp, tn)
            ppv = calculate_positive_predval(tp, fp)
            npv = calculate_negative_predval(tn, fn)
            fpr = calculate_false_positive_rate(specificity)
            fnr = calculate_false_negative_rate(sensitivity)
            fomir = calculate_false_omission_rate(npv)
            fdisr = calculate_false_discovery_rate(ppv)
            mcc = calculate_mcc(sensitivity, specificity, ppv, npv, fnr, fpr, fomir, fdisr)
            write_file(var["output_file"], "$cluster $consensus_protein $mutated_protein $method $consistency $sensitivity $specificity $ppv $npv $fpr $fnr $fomir $fdisr $mcc")
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()