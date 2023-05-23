using ArgParse
using ProgressBars
using DelimitedFiles
using DataFrames
using FASTX
using BioSequences

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Directory with clusters containing SSPro8 predictions"
            required = true
        "--extension", "-e"
            help = "SSPro8 output files' extension. Default .ss8"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

function readsspro8(pred_path)
    open(pred_path, "r") do reader
        readline(reader) # ignore first line
        seq = readline(reader)
        pred = readline(reader)
        return seq, pred
    end
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if isnothing(parsed_args["extension"])
    parsed_args["extension"] = ".ss8"
end
for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if endswith(f, parsed_args["extension"])
            f_path = joinpath(root,f)
            prediction_dir = last(split(dirname(f_path), '/'))
            if prediction_dir == "sspro8"
                f_noext = splitext(f)[1]
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_dir = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                f_out_path = joinpath(f_out_dir, "$(f_noext).sspfa")
                if !isfile(f_out_path)
                    seq, pred_str = readsspro8(f_path)
                    #Write fasta file with single record id from filename
                    mkpath(f_out_dir)
                    FASTA.Writer(open(f_out_path, "w")) do writer
                        write(writer, FASTA.Record("sspro8_$(f_noext)", LongCharSeq(pred_str)))
                    end
                end
            end
        end
    end
end
