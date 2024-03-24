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
            #default = ".pdb.mmcif"
        "--mutation_file", "-m"
            help = "Mutation file basename"
            default = "mutations.txt"
    end
    return parse_args(s)
end

input_conditions(a,f) = return startswith(basename(f), "Cluster")
#input_conditions(a,f) = return startswith(parent_dir(f), "Cluster") && basename(f) in ["af2", "colabfold", "esmfold", "rgn2"]

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "bfactors"; fext=".txt", cdir=var["input_basename"])
    #input_dir_out_preprocess!(var, "confidence_factors"; fext=".txt", cdir=var["input_basename"])
end

function commands(args, var)
    #cluster_dir = dirname(var["abs_input_dir"])
    #tool = basename(var["abs_input_dir"])
    mutation_file = joinpath(var["abs_input_dir"], args["mutation_file"]) #cluster_dir
    if !isfile(mutation_file)
        throw(ErrorException("Mutation file not found: $mutation_file"))
    end
    mutations = read_mutations(mutation_file)
    for type in ["1d", "2d", "3d", "contact"]
        mutations_vicinity_file = joinpath(var["abs_input_dir"], get_vicinity_type_filename("cluster", type)) #cluster_dir
        mut_vic_indices = read_mutations_vicinity_file(mutations_vicinity_file)
        non_local_file = joinpath(var["abs_input_dir"], get_vicinity_type_filename("non_local", type)) #cluster_dir
        nl_indices = read_vicinity_file(non_local_file)
        for mutation in mutations
            mut = "$(mutation.from)$(mutation.position)$(mutation.to)"
            mut_indices = mut_vic_indices[mut]
            for protein in mutation.proteins
                protein_file = joinpath(var["abs_input_dir"], "$protein$(args["extension"])")
                struc = read(protein_file, MMCIF)
                calphas = collectatoms(struc, calphaselector)
                for (i, ca) in enumerate(calphas)
                    res_num = i
                    bfactor = split(pdbline(ca), ' ', keepempty=false)[end-1]
                    vicinity = ""
                    if length(searchsorted(mut_indices, i)) !== 0
                        vicinity = "local"
                    elseif length(searchsorted(nl_indices, i)) !== 0
                        vicinity = "non_local"
                    end
                    write_file(var["output_file"], "$mut $vicinity $type $res_num $bfactor")
                    #write_file(var["output_file"], "$tool $mut $vicinity $type $res_num $bfactor")
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