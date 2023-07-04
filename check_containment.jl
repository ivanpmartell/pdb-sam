using ArgParse
using Glob
using ProgressBars
using BioSequences
using DataFrames
using FASTX

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster folders with fasta files required"
            required = true
        "--check_file", "-c"
            help = "Path to file to check containment of records from clusters"
            required = true
    end
    return parse_args(s)
end

function read_fasta_in_dir(cluster_dir)
    fa_records = Vector{FASTA.Record}()
    for f_path in glob("*.fa", cluster_dir)
        FASTA.Reader(open(f_path)) do reader
            append!(fa_records, collect(reader))
        end
    end
    return fa_records
end

function check_fasta_file(dir, cluster_fas)
    duplicates = Dict{String, Vector{FASTA.Record}}()
    FASTA.Reader(open(parsed_args["check_file"])) do reader
        for check_record in reader
            for fa_rec in cluster_fas
                fa_rec_id = lowercase(first(split(identifier(fa_rec), '_')))
                if occursin(fa_rec_id, lowercase(identifier(check_record)))
                    try
                        push!(duplicates[dir], fa_rec)
                    catch e
                        duplicates[dir] = [fa_rec]
                    end
                end
            end
        end
    end
    return duplicates
end

function check_txt_file(dir, cluster_fas)
    duplicates = Dict{String, Vector{FASTA.Record}}()
    open(parsed_args["check_file"]) do reader
        for check_record in eachline(reader)
            for fa_rec in cluster_fas
                fa_rec_id = lowercase(first(split(identifier(fa_rec), '_')))
                check_rec_id = lowercase(first(split(check_record, '_')))
                if occursin(fa_rec_id, check_rec_id)
                    try
                        push!(duplicates[dir], fa_rec)
                    catch e
                        duplicates[dir] = [fa_rec]
                    end
                end
            end
        end
    end
    return duplicates
end

parsed_args = parse_commandline()

amount_dups = 0
total_amount = 0
for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for dir in dirs
        if startswith(dir, "Cluster")
            cluster_dir = joinpath(root, dir)
            cluster_fas = read_fasta_in_dir(cluster_dir)
            duplicates = Dict{String, Vector{FASTA.Record}}()
            if last(splitext(parsed_args["check_file"])) == ".fa" || last(splitext(parsed_args["check_file"])) == ".fasta"
                duplicates = check_fasta_file(dir, cluster_fas)
            elseif last(splitext(parsed_args["check_file"])) == ".txt"
                duplicates = check_txt_file(dir, cluster_fas)
            else
                throw(ErrorException("Check file has an unknown format"))
            end
            global total_amount += 1
            if !isempty(duplicates)
                global amount_dups += 1
                println(duplicates)
                #Write to file (.csv)
            end
        end
    end
end
println("$(amount_dups) out of $(total_amount) were found in $(basename(parsed_args["check_file"]))")