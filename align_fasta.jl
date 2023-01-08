using ArgParse
using ProgressBars

#Clean gaps(-) from fasta file into any(X) before using this script (gap_to_x.jl)
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Fasta files should be here (recursive)"
            required = true
        "--output", "-o"
            help = "Output directory. Alignment files (fasta format) will be saved here. Ignore to write files in input directory"
            required = false
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
mkpath(parsed_args["output"])

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if f == "cif_sequences.fa"
            f_path = joinpath(root,f)
            f_path_no_root_folder = replace(f_path, Regex("^$(parsed_args["input"])")=>"")
            f_out_path = joinpath(parsed_args["output"], "$f_path_no_root_folder.ala")
            if !(isdir(dirname(f_out_path)))
                mkpath(dirname(f_out_path))
            end
            run(`clustalo --outfmt fasta --force -v --log=$(joinpath(parsed_args["output"], "clustalo.log")) -i $f_path -o $f_out_path`)
        end
    end
end