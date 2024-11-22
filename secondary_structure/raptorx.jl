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
        "--raptorx_dir", "-r"
            help = "Directory containing RaptorX Predict Property repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--clean", "-c"
            help = "Remove unnecessary output files from RaptorX Predict Property"
            action = :store_true

    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".ss8", cdir="raptorx/")
end

function commands(args, var)
    out_dir = joinpath(var["abs_output_dir"], var["input_noext"])
    raptorx = joinpath(args["raptorx_dir"], "Predict_Property.sh")
    run(`$(raptorx) -i $(var["input_path"]) -o $out_dir`)
    raptorx_out_file = joinpath(out_dir, "$(var["input_noext"]).ss8")
    if isfile(raptorx_out_file)
        mv(raptorx_out_file, var["output_file"])
        if args["clean"]
            rm(out_dir, recursive=true)
        end
    else
        throw(ErrorException("RaptorX output not found"))
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()