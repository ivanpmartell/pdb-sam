using ArgParse
using Glob
using ProgressBars

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cleaned alignment files (fasta format) will be saved here. Ignore to overwrite files in input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
mkpath(parsed_args["output"])
for f in ProgressBar(glob("*.ala", parsed_args["input"]))
    f_path = last(split(f, "/"))
    out_path = joinpath(parsed_args["output"], f_path)
    f_out = read(`sed '/^[^>]/ s/X/-/g' $f`, String)
    write(out_path, f_out)
end