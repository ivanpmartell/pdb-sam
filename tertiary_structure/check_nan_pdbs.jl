using BioStructures
using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
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

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"])
end

function commands(f_path)
    struc = read(f_path, PDB)
    atoms = collectatoms(struc)
    for atom in atoms
        if any(isnan, coords(atom))
            if parsed_args["clean"]
                rm(f_path)
            end
            throw(Exception("Atoms with undefined coordinates found in file.")) 
        end
    end
end

look_at_files(parsed_args["input"], input_conditions, commands)
