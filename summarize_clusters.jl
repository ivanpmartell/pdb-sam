using ArgParse
using ProgressBars
using FASTX
using BioSequences

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Directory with clusters containing normalized 2d structure and predictions"
            required = true
        "--results_extension", "-r"
            help = "DSSP normalized output files' extension. Default .res"
        "--seqs_extension", "-s"
            help = "SSP normalized output files' extension. Default .fa.ala"
        "--mut_extension", "-m"
            help = "SSP normalized output files' extension. Default .mut"
        "--output", "-o"
            help = "Output directory where the agglomerated fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if isnothing(parsed_args["results_extension"])
    parsed_args["results_extension"] = ".res"
end
if isnothing(parsed_args["seqs_extension"])
    parsed_args["seqs_extension"] = ".ala"
end
if isnothing(parsed_args["mut_extension"])
    parsed_args["mut_extension"] = ".mut"
end

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for dir in dirs
        if startswith(dir, "Cluster")
            cluster_dir = joinpath(root, dir)
            f_path_no_root_folder = lstrip(replace(cluster_dir, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = joinpath(parsed_args["output"], f_path_no_root_folder)
            f_out_path = joinpath(f_out_dir, "$(dir).summary")
            cluster_results = Dict{String, Dict{String, String}}()
            cluster_records = []
            cluster_mutations = Vector{String}()
            tool_set = Set()
            for (clstr_root, clstr_dirs, clstr_files) in walkdir(cluster_dir)
                for f in clstr_files
                    f_noext, f_ext = splitext(f)
                    f_path = joinpath(clstr_root, f)
                    if f_ext == parsed_args["results_extension"]
                        FASTA.Reader(open(f_path, "r")) do reader
                            for record in reader
                                id, chain, tool = split(identifier(record), '_', limit=3)
                                push!(tool_set, tool)
                                current_id = "$(id)_$(chain)"
                                try
                                    cluster_results[current_id][tool] = sequence(String, record)
                                catch e
                                    if isa(e, KeyError)
                                        cluster_results[current_id] = Dict(tool => sequence(String, record))
                                    else
                                        print("Unexpected error occured: $e")
                                        exit(1)
                                    end
                                end
                            end
                        end
                    elseif f_ext == parsed_args["seqs_extension"]
                        FASTA.Reader(open(f_path, "r")) do reader
                            cluster_records = collect(reader)
                        end
                    elseif f_ext == parsed_args["mut_extension"]
                        open(f_path, "r") do reader
                            cluster_mutations = readlines(reader)
                        end
                    end
                end
            end
            delete!(tool_set, "dssp")
            tools = collect(tool_set)

            if !isempty(cluster_results) && !isempty(cluster_records) && !isempty(cluster_mutations)
                header = "$(dir) - $(length(cluster_records)) proteins - $(length(cluster_mutations)) mutation(s)"
                open(f_out_path, "w") do writer
                    println(writer, header)
                    columns = join(append!(["#id", "sequence", "dssp"], tools), '\t')
                    println(writer, columns)
                end
            else
                println("All necessary files were not found for $(dir)")
                continue
            end
            for mutation in cluster_mutations
                pos_regex = r"\w(\d+)\w"
                position = parse(Int64, match(pos_regex, mutation).captures[1])
                open(f_out_path, "a") do writer
                    println(writer, "-$(mutation)")
                    for protein in cluster_records
                        id = identifier(protein)
                        protein_seq = sequence(String, protein)
                        tool_results = []
                        for tool in tools
                            push!(tool_results, cluster_results[id][tool][position])
                        end
                        println(writer, join(append!([id, protein_seq[position], cluster_results[id]["dssp"][position]], tool_results), '\t'))
                    end

                    println(writer, "+$(mutation)")
                    for protein in cluster_records
                        id = identifier(protein)
                        protein_seq = sequence(String, protein)
                        tool_results = []
                        for tool in tools
                            push!(tool_results, cluster_results[id][tool][position-5:position+5])
                        end
                        println(writer, join(append!([id, protein_seq[position-5:position+5], cluster_results[id]["dssp"][position-5:position+5]], tool_results), '\t'))
                    end
                end
            end
        end
    end
end
