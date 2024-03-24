using ArgParse
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--overwrite", "-w"
            help = "Overwrite previous output"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with secondary structure assignment files required"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--extension", "-e"
            help = "Secondary structure assignment file extension"
            default = ".ssfa"
        "--filter_helper", "-f"
            help = "Filter script helper file path. Under helpers: filter_x_gaf.sh"
            required = true
        "--gaf_file", "-g"
            help = "Path to gaf file with gene ontology for PDB entries"
            required = true
    end
    return parse_args(s)
end

input_conditions(a,f) = return startswith(basename(f), "Cluster")

function initialize!(args, var)
    log_initialize!(args, var)
    var["filtered_gaf"] = get_filtered_gaf(args, var)
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "protein_properties"; fext=".txt", cdir=var["input_basename"])
end

function get_filtered_gaf(args, var)
    cmd_out = read(`bash $(args["filter_helper"]) $(var["abs_input"]) $(args["gaf_file"])`, String)
    result = Dict{String, Tuple{Set{String},Set{String}}}() #protein => ({gene ontology}, {taxon})
    for line in split(cmd_out, '\n')
        vals = split(line, '\t')
        if length(vals) < 13
            continue
        end
        protein = lowercase(vals[2])
        qualifier = lowercase(vals[4])
        gene_ontology = uppercase(vals[5])
        taxon = lowercase(vals[13])
        if haskey(result, protein)
                push!(first(result[protein]), gene_ontology)
                push!(last(result[protein]), taxon)
        else
            result[protein] = (Set([gene_ontology]), Set([taxon]))
        end
    end
    return result
end

function commands(args, var)
    for prot in process_input(var["input_path"], 'f'; input_conditions=(a,x)->has_extension(x, args["extension"]), silence=true)
        protein = remove_ext(basename(prot))
        pkey = lowercase(protein)
        if !haskey(var["filtered_gaf"], pkey)
            continue
        end
        for taxon in last(var["filtered_gaf"][pkey])
            write_file(var["output_file"], "$protein $taxon")
        end
        for go in first(var["filtered_gaf"][pkey])
            write_file(var["output_file"], "$protein $go")
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!, overwrite=parsed_args["overwrite"])
    return 0
end

main()