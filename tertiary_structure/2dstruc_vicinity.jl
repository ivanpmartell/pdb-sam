using BioStructures
using BioSequences
using Plots
using ArgParse
include("../common.jl")

ENV["GKSwstype"]="nul"

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-s"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.pdb'"
            required = true
        "--mut_file", "-m"
            help = "Filename of mutations file. Usually ending in '.mut'"
            required = true

    end
    return parse_args(s)
end

parsed_args = parse_commandline()

#Read mutation file (get res numbers)
function read_mutation_file(mutation_f_path)
    cluster_mutations = readlines(mutation_f_path)
    mutations_dict = Dict{Int64,Array{Tuple{Char, Char}}}()
    for mutation in cluster_mutations
        pos_regex = r"(\w)(\d+)(\w)"
        from_str, pos_str, to_str = match(pos_regex, mutation).captures
        position = parse(Int64, pos_str)
        from = only(from_str)
        to = only(to_str)
        try
            push!(mutations_dict[position], (from, to))
        catch e
            mutations_dict[position] = [(from, to)]
        end
    end
    return mutations_dict
end

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"])
end

function commands(f_path) #, f_noext, f_out
    parent_dir = dirname(dirname(f_path))
    if startswith(last(splitdir(parent_dir)), "Cluster")
        struc = read(f_path, PDB)
        calphas = collectatoms(struc, calphaselector)
        mut_file = joinpath(parent_dir, parsed_args["mut_file"])
        mutations =  read_mutation_file(mut_file)#dict of mutation from other file
        #Obtain vicinity of each mutation (check angstrom distance to use)
        vicinity = Dict()
        for mut_pos in keys(mutations)
            for at in calphas
                 #dict of res_num and list of calphas in its vicinity
                 distance_to_mut = distance(struc['A'][mut_pos], at)
                if distance_to_mut < 13.0 && resnumber(at) != mut_pos #MIGHT NEED TO CHANGE A TO FIRST KEY OF STRUC
                    #Add to vicinity dict
                    try
                        push!(vicinity[mut_pos], (at, distance_to_mut))
                    catch e
                        vicinity[mut_pos] = [(at, distance_to_mut)]
                    end
                    #print / write in file the vicinity of each mutation
                    println(pdbline(at))
                end
            end
            #plot the vicinity for each mutation
            p = plot(
                resnumber.(first.(vicinity[mut_pos])), #vicinity list for that res number
                last.(vicinity[mut_pos]), #vicinity list for mutation
                xlabel="Residue position",
                ylabel="Distance to mutation at $(mut_pos)",
                label="",
            )
            plot!(resnumber.(first.(vicinity[mut_pos])), last.(vicinity[mut_pos]), seriestype=:scatter, label="Cα")
            savefig(p, "junk_test/plotting_$(last(splitdir(f_path)))_$(mut_pos).png")
        end
    end
end

work_on_input_files(parsed_args["input"], input_conditions, commands, parsed_args["skip_error"])