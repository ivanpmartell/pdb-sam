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
            help = "Directory with clusters containing Spot1D-LM predictions"
            required = true
        "--extension", "-e"
            help = "Spot1D-LM output files' extension. Usually .csv"
            required = true
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if endswith(f, parsed_args["extension"])
            f_path = joinpath(root,f)
            prediction_dir = last(split(dirname(f_path), '/'))
            if prediction_dir == "spot1d_lm"
                f_noext = splitext(f)[1]
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_dir = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                f_out_path = joinpath(f_out_dir, "$(f_noext).sspfa")
                if !isfile(f_out_path)
                    data, data_header = readdlm(f_path, ',', header=true)
                    data_cols = lowercase.(vec(data_header))
                    data_cols[1] = "idx"
                    pred_df = DataFrame(data, data_cols)
                    pred_array = pred_df[:, "ss8"]
                    pred_str = join(pred_array)
                    #Write fasta file with single record id from filename
                    mkpath(f_out_dir)
                    FASTA.Writer(open(f_out_path, "w")) do writer
                        write(writer, FASTA.Record(f_noext, LongCharSeq(pred_str)))
                    end
                end
            end
        end
    end
end
