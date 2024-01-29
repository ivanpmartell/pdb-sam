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
            help = "Directory with clusters containing Spot1D predictions"
            required = true
        "--extension", "-e"
            help = "Spot1D output files' extension. Default .spot1d"
            default = ".spot1d"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && last(splitdir(dirname(f))) == "spot1d"

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext="sspfa")
end

function commands(args, var)
    data, data_header = readdlm(var["input_path"], '\t', header=true)
    data_cols = lowercase.(vec(data_header))
    data_cols[1] = "idx"
    pred_df = DataFrame(data, data_cols)
    pred_array = pred_df[:, "ss8"]
    pred_str = join(pred_array)
    #Write fasta file with single record id from filename
    FASTA.Writer(open(var["output_file"], "w")) do writer
        write(writer, FASTA.Record("$(var["input_noext"])_spot1d", LongCharSeq(pred_str)))
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()