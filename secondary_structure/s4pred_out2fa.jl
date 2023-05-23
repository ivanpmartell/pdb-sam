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
            help = "Directory with clusters containing S4Pred predictions"
            required = true
        "--extension", "-e"
            help = "S4Pred output files' extension. Default .ss2"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if isnothing(parsed_args["extension"])
    parsed_args["extension"] = ".ss2"
end
for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if endswith(f, parsed_args["extension"])
            f_path = joinpath(root,f)
            prediction_dir = last(split(dirname(f_path), '/'))
            if prediction_dir == "s4pred"
                f_noext = splitext(f)[1]
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_dir = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                f_out_path = joinpath(f_out_dir, "$(f_noext).sspfa")
                if !isfile(f_out_path)
                    delimited = readdlm(f_path, ' ', comments=true)
                    predictions = Matrix{Any}(undef, size(delimited, 1), 6)
                    for i in axes(delimited, 1)
                        predictions[i, :] = filter(!isempty, delimited[i, :])
                    end
                    pred_df = DataFrame(predictions, ["idx", "aa", "ss3", "pC", "pH", "pE"])
                    pred_array = pred_df[:, "ss3"]
                    pred_str = join(pred_array)
                    #Write fasta file with single record id from filename
                    mkpath(f_out_dir)
                    FASTA.Writer(open(f_out_path, "w")) do writer
                        write(writer, FASTA.Record("s4pred_$(f_noext)", LongCharSeq(pred_str)))
                    end
                end
            end
        end
    end
end
