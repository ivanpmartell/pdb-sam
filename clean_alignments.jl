using ArgParse
using Glob
using FASTX
using BioSequences

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cleaned alignment files (fasta format) will be saved here. Ignore to overwrite files in input directory"
    end
    return parse_args(s)
end

function write_clean_records(str_input, out_path)
    unique_seqs = Set()
    FASTA.Writer(open(out_path, "w")) do writer
        FASTA.Reader(IOBuffer(str_input)) do reader
            for record in reader
                if !in(sequence(LongAA, record), unique_seqs)
                    push!(unique_seqs, sequence(LongAA, record))
                    write(writer, record)
                else
                    println("Removed duplicate sequence $(identifier(record)) on $out_path")
                end
            end
        end
    end
    if length(unique_seqs) == 1
        rm(out_path)
        println("Deleted singleton cluster: $out_path")
    end
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
mkpath(parsed_args["output"])
singleton_clusters = 0
for f in glob("*.ala", parsed_args["input"])
    f_path = last(split(f, "/"))
    out_path = joinpath(parsed_args["output"], f_path)
    f_out = read(`sed '/^[^>]/ s/X/-/g' $f`, String)
    write_clean_records(f_out, out_path)
end