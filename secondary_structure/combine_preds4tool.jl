#For each tool prediction in a cluster, combine all sspfa and ssfa files into one
using ArgParse
using ProgressBars
using FASTX
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Directory with clusters containing normalized 2d structure and predictions"
            required = true
        "--dssp_extension", "-d"
            help = "DSSP normalized output files' extension. Default .ssfa"
            default = ".ssfa"
        "--pred_extension", "-p"
            help = "SSP normalized output files' extension. Default .sspfa"
            default = ".sspfa"
        "--output", "-o"
            help = "Output directory where the agglomerated fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

input_dir_conditions(a,d) = return startswith(d, "Cluster")
input_conditions(a,f) = return has_extension(f, [a["dssp_extension"], a["pred_extension"]])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".ssfa")
end

function commands(args, var)
    dssp_res_files = Set{String}()
    pred_res_files = Dict{String, Set{String}}()
    cluster_tool_dirs = Dict{String, String}()
    for f in process_input(var["input_path"], 'f'; input_conditions=input_conditions, script_args=args, nested=true)
        f_path = joinpath(var["input_path"], f)
        f_noext, f_ext = basename_ext(f)
        if f_ext == parsed_args["dssp_extension"]
            push!(dssp_res_files, f_path)
        elseif f_ext == parsed_args["pred_extension"]
            tool = last(splitdir(f))
            try
                push!(pred_res_files[tool], f_path)
            catch e
                if isa(e, KeyError)
                    pred_res_files[tool] = Set([f_path])
                else
                    print("Unexpected error occured: $e")
                    exit(1)
                end
            end
        end
    end
    for tool in process_directories(var["input_path"], default_input_condition, args, false)
        tool_dir = joinpath(var["input_path"], tool)
        if tool in keys(pred_res_files)
            f_out_dir = keep_input_dir_structure(var["abs_input"], var["abs_output"], var["input_path"], "")
            f_out_path = joinpath(f_out_dir, "$(tool).toolres")
            if !isfile(f_out_path)
                mkpath(f_out_dir)
                for f_path in dssp_res_files
                    FASTA.Reader(open(f_path, "r")) do reader
                        records = collect(reader)
                        for rec in records
                            FASTA.Writer(open(f_out_path, "a")) do writer
                                write(writer, rec)
                            end
                        end
                    end
                end
                for f_path in pred_res_files[tool]
                    FASTA.Reader(open(f_path, "r")) do reader
                        records = collect(reader)
                        for rec in records
                            FASTA.Writer(open(f_out_path, "a")) do writer
                                write(writer, rec)
                            end
                        end
                    end
                end
            end
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_dir_conditions, preprocess=preprocess!)
    return 0
end

main()