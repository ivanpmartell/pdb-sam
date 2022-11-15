using ArgParse
using FASTX
using BioSequences

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input file (fasta format)"
            required = true
        "--output", "-o"
            help = "Output file (fasta format)"
            required = true
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
seqs = Set()
onlyX = Regex("^X+\$")
#Removes non-protein sequences and identical sequences
FASTA.Writer(open(parsed_args["output"], "w")) do writer
    FASTA.Reader(open(parsed_args["input"])) do reader
        for record in reader
            try
                if occursin("mol:protein", description(record)) &&
                        !in(sequence(LongAA, record), seqs) &&
                        isnothing(match(onlyX, sequence(String, record)))
                    write(writer, record)
                    push!(seqs, sequence(LongAA, record))
                end
            catch e
                println("Skipping record (malformed)")
            end
        end
    end
end