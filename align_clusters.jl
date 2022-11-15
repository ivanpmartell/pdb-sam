using ArgParse
using Glob
using ProgressBars

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cluster alignment files (fasta format) will be saved here"
            required = true
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
mkpath(parsed_args["output"])

for f in ProgressBar(glob("*.fa", parsed_args["input"]))
    f_path = last(split(f, "/"))
    run(`clustalo --outfmt fasta --force -i $f -o $(joinpath(parsed_args["output"], "$f_path.ala"))`)
end