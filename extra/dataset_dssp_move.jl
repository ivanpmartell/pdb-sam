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
            help = "Extension for input files. Default '.fa'"
            default = ".fa"
        "--dssp_assigned_dir", "-d"
            help = "Directory containing DSSP assigned proteins"
            required = true
        "--dssp_extension", "-x"
            help = "Extension for dssp assignment files. Default '.mmcif'"
            default = ".mmcif"
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=args["dssp_extension"])
end

function commands(args, var)
    id, _ = split(var["input_noext"], '_')
    assigned_file_lower = joinpath(args["dssp_assigned_dir"], "$(lowercase(id))$(args["dssp_extension"])")
    assigned_file_upper = joinpath(args["dssp_assigned_dir"], "$(uppercase(id))$(args["dssp_extension"])")
    if isfile(assigned_file_lower)
        cp(assigned_file_lower, var["output_file"], force=true)
    elseif isfile(assigned_file_upper)
        cp(assigned_file_upper, var["output_file"], force=true)
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!, runtime_unit="sec")
    return 0
end

main()