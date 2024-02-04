using ArgParse
include("./common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Fasta files should be here (recursive)"
            required = true
        "--prefix", "-p"
            help = "Prefix to append to output filename"
            required = false
            default = ""
        "--suffix", "-s"
            help = "Suffix to append to output filename"
            required = false
            default = ""
        "--output", "-o"
            help = "Output directory. Modified files (fasta format) will be saved here. Ignore to write files in input directory"
            required = false
        "--reverse", "-r"
            action = :store_true
        "--extension", "-e"
            help = "File format that will be processed in the input directory"
            required = false
            default = ".fa"
    end
    return parse_args(s)
end

input_conditions(a,f) = has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "$(args["prefix"])$(basename(var["input_path"]))$(args["suffix"])")
end

function commands(args, var)
    if args["reverse"]
        cmd = `sed '/^[^>]/ s/X/-/g' $(var["input_path"])`
    else
        cmd = `sed '/^[^>]/ s/-/X/g' $(var["input_path"])`
    end
    f_out = read(cmd, String)
    open(var["output_file"], "w") do file
        write(file, f_out)
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()