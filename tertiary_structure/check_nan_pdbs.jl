using BioStructures
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
            help = "Extension for input files. Usually '.pdb'"
            required = true
        "--clean", "-c"
            help = "Remove files that contain NaN coordinates"
            action = :store_true

    end
    return parse_args(s)
end

input_conditions(a,f) = has_extension(f, a["extension"])

function initialize!(args, var)
    var["undef_coord_files"] = 0
    var["error_file"] = joinpath(var["abs_input"], "undef.err")
end

function commands(args, var)
    struc = read(var["input_path"], PDB)
    atoms = collectatoms(struc)
    for atom in atoms
        if any(isnan, coords(atom))
            if args["clean"]
                rm(var["input_path"])
            end
            var["undef_coord_files"] += 1
            throw(ErrorException("Undefined coordinates: $(var["input_path"])"))
        end
    end
end

function finalize(args, var)
    println("Atoms with undefined coordinates found in $(var["undef_coord_files"]) files.")
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, finalize=finalize)
    return 0
end

main()