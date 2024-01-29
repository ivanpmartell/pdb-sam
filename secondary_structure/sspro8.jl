using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--sspro8_dir", "-s"
            help = "Directory containing SSPro8 repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"], "ss8", "sspro8/")
end

function commands(args, var)
    sspro8 = joinpath(args["sspro8_dir"], "bin/run_scratch1d_predictors.sh")
    f_out_path = remove_ext(var["output_file"])
    run(`$(sspro8) --input_fasta $(var["input_path"]) --output_prefix $(f_out_path)`)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()