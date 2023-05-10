using ArgParse
using Glob
using FASTX
using BioSequences
using ProgressBars

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Fasta files should be inside"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
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
    FASTA.Reader(open(in_path)) do reader
        for record in reader
            num_records += 1
            out_file = joinpath(parsed_args["output"], "$(identifier(record)).fa")
            seq = sequence(LongAminoAcidSeq, record)
            seq_len = count(iscertain, seq)
            #seq_len = length(seq)
            rec_len = extract_len(description(record))
            if seq_len === rec_len
                full_len_records += 1
            end
            if parsed_args["separate"]
                FASTA.Writer(open(out_file, "w")) do writer
                    write(writer, record)
                end
            end
        end
    end
    if num_records > 0
        return full_len_records == num_records
    else
        return False
    end
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
mkpath(dirname(parsed_args["output"]))

full_length_cluster_count = 0
if parsed_args["nested"]
    for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
        for f in files
            if endswith(f, parsed_args["extension"])
                f_path = joinpath(root,f)
                if separate_records(f_path)
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