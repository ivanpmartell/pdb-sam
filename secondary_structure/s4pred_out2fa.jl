using ArgParse
using DelimitedFiles
using DataFrames
using FASTX
using BioSequences
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Directory with clusters containing S4Pred predictions"
            required = true
        "--extension", "-e"
            help = "S4Pred output files' extension. Default .ss2"
            default = ".ss2"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && parent_dir(f) == "s4pred"

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".sspfa")
end

function commands(args, var)
    delimited = readdlm(var["input_path"], ' ', comments=true)
    predictions = Matrix{Any}(undef, size(delimited, 1), 6)
    for i in axes(delimited, 1)
        predictions[i, :] = filter(!isempty, delimited[i, :])
    end
    pred_df = DataFrame(predictions, ["idx", "aa", "ss3", "pC", "pH", "pE"])
    pred_array = pred_df[:, "ss3"]
    pred_str = join(pred_array)
    #Write fasta file with single record id from filename
    FASTA.Writer(open(var["output_file"], "w")) do writer
        write(writer, FASTA.Record("$(var["input_noext"])_s4pred", pred_str))
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()