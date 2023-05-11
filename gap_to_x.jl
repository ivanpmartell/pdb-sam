using ArgParse
using ProgressBars

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Fasta files should be here (recursive)"
            required = true
        "--prefix", "-p"
            help = "Prefix to append to output filename"
            required = false
        "--suffix", "-s"
            help = "Suffix to append to output filename"
            required = false
        "--output", "-o"
            help = "Output directory. Modified files (fasta format) will be saved here. Ignore to write files in input directory"
            required = false
        "--reverse", "-r"
            action = :store_true
        "--format", "-f"
            help = "File format that will be processed in the input directory"
            required = false
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if isnothing(parsed_args["prefix"])
    parsed_args["prefix"] = ""
end
if isnothing(parsed_args["suffix"])
    parsed_args["suffix"] = ""
end
mkpath(parsed_args["output"])
if isnothing(parsed_args["format"])
    parsed_args["format"] = ".fa"
end

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if endswith(f, "$(parsed_args["format"])")
            f_path = joinpath(root,f)
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = dirname(f_path_no_root_folder)
            f_out_name = basename(f_path_no_root_folder)
            f_out_name = "$(parsed_args["prefix"])$(f_out_name)$(parsed_args["suffix"])"
            f_out_complete = joinpath(f_out_dir, f_out_name)
            if parsed_args["reverse"]
                cmd = `sed '/^[^>]/ s/X/-/g' $f_path`
            else
                cmd = `sed '/^[^>]/ s/-/X/g' $f_path`
            end
            f_out = read(cmd, String)
            f_out_path = joinpath(parsed_args["output"], f_out_complete)
            if !(isfile(f_out_path))
                mkpath(dirname(f_out_path))
                touch(f_out_path)
            end
            open(f_out_path, "w") do file
                write(file, f_out)
            end
        end
    end
end