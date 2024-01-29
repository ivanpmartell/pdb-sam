using ArgParse
using BioSequences
using FASTX
include("./common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with fasta files required"
            required = true
        "--check_file", "-c"
            help = "Path to file to check containment of records from clusters"
            required = true
    end
    return parse_args(s)
end

fasta_ext(f) = return has_extension(f, ".fa")

function read_fasta_in_dir(cluster_dir)
    fa_records = Vector{FASTA.Record}()
    for f_path in process_files(cluster_dir, fasta_ext)
        FASTA.Reader(open(f_path)) do reader
            append!(fa_records, collect(reader))
        end
    end
    return fa_records
end

function check_fasta_file(check_file, dir, cluster_fas)
    duplicates = Dict{String, Vector{FASTA.Record}}()
    FASTA.Reader(open(check_file)) do reader
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

function check_txt_file(check_file, dir, cluster_fas)
    duplicates = Dict{String, Vector{FASTA.Record}}()
    open(check_file) do reader
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

input_conditions(a,d) = return startswith(d, "Cluster")

function initialize!(args, var)
    var["amount_dups"] = 0
    var["total_amount"] = 0
    var["error_file"] = "$(args["check_file"]).err"
end

function finalize(args, var)
    println("$(var["amount_dups"]) out of $(var["total_amount"]) were found in $(basename(args["check_file"]))")
end

function commands(args, var)
    cluster_fas = read_fasta_in_dir(var["input_path"])
    duplicates = Dict{String, Vector{FASTA.Record}}()
    if last(splitext(args["check_file"])) == ".fa" || last(splitext(args["check_file"])) == ".fasta"
        duplicates = check_fasta_file(args["check_file"], var["input_basename"], cluster_fas)
    elseif last(splitext(args["check_file"])) == ".txt"
        duplicates = check_txt_file(args["check_file"], var["input_basename"], cluster_fas)
    else
        throw(ErrorException("Check file has an unknown format"))
    end
    var["total_amount"] += 1
    if !isempty(duplicates)
        var["amount_dups"] += 1
        println("Amount of duplicates: $(duplicates)")
        #TODO:Write to file (.csv)
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, initialize=initialize!, finalize=finalize, nested=false)
    return 0
end

main()