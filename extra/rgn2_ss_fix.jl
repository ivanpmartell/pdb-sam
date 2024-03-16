using ArgParse
using BioStructures
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with fasta files required"
            required = true
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, ".fa") && startswith(parent_dir(f), "Cluster")

function preprocess!(args, var)
    file_preprocess!(var; input_only=true)
end

function commands(args, var)
    fa_record = read_fasta(var["input_path"])
    len = length(sequence(fa_record))
    rgn2_sspfa = joinpath(var["abs_input_dir"], "rgn2/", "$(var["input_noext"]).sspfa")
    pred_record = read_fasta(rgn2_sspfa)
    fix_sequence = sequence(pred_record)
    pred_len = length(fix_sequence)
    if len !== pred_len
        difference_len = len - pred_len
        fix_sequence *= repeat('C', difference_len)
        FASTA.Writer(open(rgn2_sspfa, "w")) do writer
            write(writer, FASTA.Record(identifier(pred_record), fix_sequence))
        end
        println("Added $difference_len C")
    else
        println("No change needed")
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()