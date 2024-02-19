using ArgParse
include("../common.jl")

#Clean gaps(-) from fasta file into any(X) before using this script (gap_to_x.jl)
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Fasta files should be here (recursive)"
            required = true
        "--output", "-o"
            help = "Output directory. Alignment files (fasta format) will be saved here. Ignore to write files in input directory"
            required = false
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa'"
            default = ".fa"
            required = false
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".ala")
end

function commands(args, var)
    log_path = joinpath(var["abs_output_dir"], "clustalo.log")
    run(`clustalo --outfmt fasta --force -v --log=$(log_path) -i $(var["input_path"]) -o $(var["output_file"])`)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!, runtime_unit="min")
    return 0
end

main()