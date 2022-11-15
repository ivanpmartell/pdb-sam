using ArgParse
using FASTX

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input file (clstr format)"
            required = true
        "--output", "-o"
            help = "Output file (clstr format)"
            required = true
        "--directory", "-d"
            help = "Output directory. Cluster files (fasta format) will be saved here"
            required = true
        "--fasta", "-f"
            help = "Input file (fasta format). If not specified, determined through .clstr input"
    end
    return parse_args(s)
end

#Read clstr file
struct ClusterProtein
    length::Int64
    pdb_id::String
    ident_pct::Float32
    is_root::Bool
end

function printClusterProtein(self::ClusterProtein, id::Int64)
    amt_ident = "*"
    if !(self.is_root)
        amt_ident = "at $(self.ident_pct)%"
    end
    return "$(id)\t$(self.length)aa, >$(self.pdb_id)... $(amt_ident)\n"
end

parsed_args = parse_commandline()
if isnothing(parsed_args["fasta"])
    parsed_args["fasta"] = chop(parsed_args["input"], tail=6)
end

cluster_dict = Dict()
cluster_regex = r"^(\d+)\t(\d+)aa, >(\w+)\.\.\. (at \d+\.\d+%|\*)$"
open(parsed_args["input"]) do file
    current_cluster = ""
    for line in eachline(file)
        if startswith(line,">")
            current_cluster = SubString(line, 2,lastindex(line))
            cluster_dict[current_cluster] = Dict()
        else
            matches = match(cluster_regex, line)
            id = parse(Int64, matches[1])
            plength = parse(Int64, matches[2])
            pdb_id = matches[3]
            is_root = matches[4] == "*"
            if is_root
                ident_pct = Float32(100.00)
            else
                ident_pct = parse(Float32, SubString(matches[4], 4, lastindex(matches[4])-1))
            end
            cluster_dict[current_cluster][id] = ClusterProtein(plength, pdb_id, ident_pct, is_root)
        end
    end
end

#Remove 100% similarity sequences in clusters
for ckey in keys(cluster_dict)
    current_cluster = cluster_dict[ckey]
    for pkey in keys(current_cluster)
        if !(current_cluster[pkey].is_root) && current_cluster[pkey].ident_pct == 100.00
            delete!(current_cluster, pkey)
        end
    end
end

#Remove singleton clusters
for ckey in keys(cluster_dict)
    if length(cluster_dict[ckey]) == 1
        delete!(cluster_dict, ckey)
    end
end

#Write pdb_clean_clustered.fa.clstr
protein_cluster = Dict()
open(parsed_args["output"], "w") do file
    for ckey in keys(cluster_dict)
        current_cluster = cluster_dict[ckey]
        write(file, ">$(ckey)\n")
        for pkey in keys(current_cluster)
            write(file, printClusterProtein(current_cluster[pkey], pkey))
            protein_cluster[current_cluster[pkey].pdb_id] = ckey
        end
    end
end

#Write separate .fa files for each cluster
mkpath(parsed_args["directory"])
FASTA.Reader(open(parsed_args["fasta"])) do reader
    for record in reader
        try
            current_cluster = protein_cluster[identifier(record)]
            FASTA.Writer(open("$(joinpath(parsed_args["directory"], current_cluster)).fa", "a")) do writer
                write(writer, record)
            end
        catch e
            msg = "Protein not in clusters"
        end
    end
end