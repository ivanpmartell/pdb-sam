using ArgParse
using BioStructures
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with secondary structure assignment files required"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--extension", "-e"
            help = "Secondary structure assignment file extension"
            default = ".mmcif"
        "--mutation_file", "-m"
            help = "Mutation file basename"
            default = "mutations.txt"
    end
    return parse_args(s)
end

input_conditions(a,f) = return startswith(basename(f), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "bfactors"; fext=".txt", cdir=var["input_basename"])
end

function commands(args, var)
    mutation_file = joinpath(var["input_path"], args["mutation_file"])
    if !isfile(mutation_file)
        throw(ErrorException("Mutation file not found: $mutation_file"))
    end
    mutations = read_mutations(mutation_file)
    for type in ["1d", "2d", "3d", "contact"]
        mutations_vicinity_file = joinpath(var["input_path"], get_vicinity_type_filename("cluster", type))
        mut_vic_indices = read_mutations_vicinity_file(mutations_vicinity_file)
        non_local_file = joinpath(var["input_path"], get_vicinity_type_filename("non_local", type))
        nl_indices = read_vicinity_file(non_local_file)
        for mutation in mutations
            mut = "$(mutation.from)$(mutation.position)$(mutation.to)"
            mut_indices = mut_vic_indices[mut]
            for protein in mutation.proteins
                protein_file = joinpath(var["input_path"], "$protein$(args["extension"])")
                id, chain = split(protein, '_')
                struc = read(protein_file, MMCIFFormat)[chain]
                calphas = collectatoms(struc, calphaselector)
                for i in eachindex(calphas)
                    bfactor = tempfactor(calphas[i])
                    vicinity = ""
                    if length(searchsorted(mut_indices, i)) !== 0
                        vicinity = "local"
                    elseif length(searchsorted(nl_indices, i)) !== 0
                        vicinity = "non_local"
                    else
                        vicinity = "global"
                    end
                    write_file(var["output_file"], "$protein $mut $vicinity $type $i $bfactor")
                end
            end
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()