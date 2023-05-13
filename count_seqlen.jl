using ArgParse
using Glob
using FASTX
using BioSequences
using ProgressBars

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
            required = true
        "--nested", "-n"
            help = "Choose this flag if fasta files are nested within directories inside input directory"
            action = :store_true
        "--separate", "-s"
            help = "Choose this flag if fasta files should be separated into one record per file"
            action = :store_true
    end
    return parse_args(s)
end

function extract_len(str)
    regex = r"length:(\d+)\s"
    regex_match = match(regex, str)
    if regex_match !== nothing
        return parse(Int, regex_match[1])
    else
        return nothing
    end
end

function separate_records(in_path)
    num_records = 0
    full_len_records = 0
    record_list = Vector{String}()
    FASTA.Reader(open(in_path)) do reader
        for record in reader
            num_records += 1
            out_file = joinpath(dirname(in_path), "$(identifier(record)).fa")
            seq = sequence(LongAminoAcidSeq, record)
            seq_len = count(iscertain, seq)
            #seq_len = length(seq)
            rec_len = extract_len(description(record))
            if seq_len === rec_len
                if count(!iscertain, seq) === 0 
                    full_len_records += 1
                end
            end
            if parsed_args["separate"]
                push!(record_list, out_file)
                FASTA.Writer(open(out_file, "w")) do writer
                    write(writer, record)
                end
            end
        end
    end
    if num_records > 0
        if full_len_records == num_records
            if !isnothing(parsed_args["output"])
                for record in record_list
                    f_out_path = parsed_args["output"]
                    if parsed_args["nested"]
                        f_path_no_root_folder = lstrip(replace(in_path, Regex("^$(parsed_args["input"])")=>""), '/')
                        f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                    end
                    mkpath(f_out_path)
                    out_file = joinpath(f_out_path, "$(basename(record))")
                    cp(record, out_file)
                    record_cif = replace(record, r".fa$"=>".cif")
                    out_cif = joinpath(f_out_path, "$(basename(record_cif))")
                    cp(record_cif, out_cif)
                end
            end
            return true
        else
            return false
        end
    else
        return false
    end
end

parsed_args = parse_commandline()

full_length_cluster_count = 0
if parsed_args["nested"]
    for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
        for f in files
            if endswith(f, parsed_args["extension"])
                f_path = joinpath(root,f)
                if separate_records(f_path)
                    if !isnothing(parsed_args["output"])
                        f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                        f_out_path = joinpath(parsed_args["output"], f_path_no_root_folder)
                        mkpath(dirname(f_out_path))
                        cp(f_path, f_out_path, force=true)
                    end
                    global full_length_cluster_count += 1
                end
            end
        end
    end
else
    for f in ProgressBar(glob("*$(parsed_args["extension"])", parsed_args["input"]))
        if separate_records(f)
            global full_length_cluster_count += 1
        end
    end
end

print(full_length_cluster_count)