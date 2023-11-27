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
            help = "File extension for DSSP normalized output. Default .res"
            default = ".res"
        "--seqs_extension", "-s"
            help = "File extension for SSP normalized output. Default .ala"
            default = ".ala"
        "--mut_extension", "-m"
            help = "File extension for cluster mutations. Default .mut"
            default = ".mut"
        "--output", "-o"
            help = "Output directory where the agglomerated fasta file will be written. Ignore to use input directory"
        "--max_range", "-x"
            help = "Maximum number of amino acids in summary. Default 15"
            default = 15
        "--min_range", "-n"
            help = "Minimum number of amino acids in summary. Default 5"
            default = 5
    end
    return parse_args(s)
end

function calc_plus(x, y, d::Char)
    return d=='r' ? x+y : x-y
end

function calc_minus(x, y, d::Char)
    return d=='r' ? x-y : x+y
end

function getrange(seq, pos, maxrange, direction::Char)
    seq_edge = direction=='r' ? length(seq) : 1
    lookup = '.'
    try
        lookup = seq[pos]
    catch e
        return pos < 1 ? 1 : length(seq)
    end
    edge = calc_plus(pos, maxrange, direction)
    for i in range(calc_plus(pos, 1, direction), edge, step=direction=='r' ? 1 : -1)
        try
            if seq[i] !== lookup
                return calc_minus(i, 1, direction)
            end
        catch e
            if isa(e, BoundsError)
                return seq_edge
            end
        end
    end
    return edge
end

function get_secondary_struct_range(seq, pos)
    #Get range of ss spanning position
    minrange = parsed_args["min_range"]
    maxrange = parsed_args["max_range"]
    ss_range_right = getrange(seq, pos, maxrange, 'r')
    ss_range_left = getrange(seq, pos, maxrange, 'l')
    #Get range of before and after ss spanning
    right_maxrange = maxrange - (ss_range_right - pos)
    left_maxrange = maxrange - (pos - ss_range_left)
    ss_on_right_range = getrange(seq, ss_range_right+1, right_maxrange, 'r')
    ss_on_left_range = getrange(seq, ss_range_left-1, left_maxrange, 'l')
    #Add to range until min range
    current_right_range = ss_on_right_range - pos
    current_left_range = pos - ss_on_left_range
    if current_left_range < minrange
        ss_on_left_range = max(1, pos-minrange)
    end
    if current_right_range < minrange
        ss_on_right_range = min(length(seq), pos+minrange)
    end
    return ss_on_left_range:ss_on_right_range
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
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
            try
                for protein in cluster_records
                    id = identifier(protein)
                    cluster_results[id]["dssp"]
                end
            catch e
                println("All necessary files were not found for $(dir)")
                continue
            end
            if !isempty(cluster_results) && !isempty(cluster_mutations) && !isempty(tools)
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
                pos_regex = r"(\w)(\d+)(\w)"
                from_str, pos_str, to_str = match(pos_regex, mutation).captures
                position = parse(Int64, pos_str)
                from = only(from_str)
                to = only(to_str)
                mutation_aas = Set([from, to])
                ss_range = 1:1
                open(f_out_path, "a") do writer
                    #TODO: ONLY ADD PROTEINS THAT APPEAR IN MUTATION
                    for protein in cluster_records
                        id = identifier(protein)
                        current_ss_range = get_secondary_struct_range(cluster_results[id]["dssp"], position)
                        if length(current_ss_range) > length(ss_range)
                            ss_range = current_ss_range
                        end
                    end
                    location_array = []
                    for i in range(1, length(tools)+2)
                        location_str = "$(' '^(position - first(ss_range)))*$(' '^(last(ss_range) - position))"
                        push!(location_array, location_str)
                    end
                    println(writer, "+$(mutation)\t$(join(location_array, '\t'))")
                    for protein in cluster_records
                        id = identifier(protein)
                        protein_seq = sequence(String, protein)
                        if protein_seq[position] in mutation_aas
                            tool_results = []
                            for tool in tools
                                push!(tool_results, cluster_results[id][tool][ss_range])
                            end
                            println(writer, join(append!([id, protein_seq[ss_range], cluster_results[id]["dssp"][ss_range]], tool_results), '\t'))
                        end
                    end

                    println(writer, "-$(mutation)")
                    for protein in cluster_records
                        id = identifier(protein)
                        protein_seq = sequence(String, protein)
                        if protein_seq[position] in mutation_aas
                            tool_results = []
                            for tool in tools
                                push!(tool_results, cluster_results[id][tool][position])
                            end
                            println(writer, join(append!([id, protein_seq[position], cluster_results[id]["dssp"][position]], tool_results), '\t'))
                        end
                    end
                end
            end
        end
    end
end
