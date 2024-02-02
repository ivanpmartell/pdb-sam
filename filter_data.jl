using ArgParse
using FASTX
using BioSequences
include("./common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input file (fasta format)"
            required = true
        "--output", "-o"
            help = "Output file (fasta format)"
            required = true
    end
    return parse_args(s)
end

function preprocess!(args, var)
    file_preprocess!(var)
end

function commands(args, var)
    seqs = Set()
    onlyX = Regex("^X+\$")
    #Removes non-protein sequences and identical sequences
    FASTA.Writer(open(var["output_file"], "w")) do writer
        FASTA.Reader(open(var["input_path"])) do reader
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
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_single(parsed_args, commands; preprocess=preprocess!, runtime_unit="sec")
    return 0
end

main()