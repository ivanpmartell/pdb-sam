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
            help = "Directory with clusters containing RaptorX predictions"
            required = true
        "--extension", "-e"
            help = "RaptorX output files' extension. Default .ss8"
            default = ".ss8"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && parent_dir(f) == "raptorx"

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".sspfa")
end

function commands(args, var)
    delimited = readdlm(var["input_path"], ' ', comments=true)
    predictions = Matrix{Any}(undef, size(delimited, 1), 11)
    for i in axes(delimited, 1)
        predictions[i, :] = filter(!isempty, delimited[i, :])
    end
    pred_df = DataFrame(predictions, ["idx", "aa", "ss8", "pH", "pG", "pI", "pE", "pB", "pT", "pS", "pC"])
    pred_df[!, "ss8"][pred_df[!, "ss8"] .== "L"] .= "C"
    pred_array = pred_df[:, "ss8"]
    pred_str = join(pred_array)
    #Write fasta file with single record id from filename
    FASTA.Writer(open(var["output_file"], "w")) do writer
        write(writer, FASTA.Record("$(var["input_noext"])_raptorx", pred_str))
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()