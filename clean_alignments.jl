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
            help = "Input directory. Cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cleaned alignment files (fasta format) will be saved here. Ignore to overwrite files in input directory"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, ".ala")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext="ala")
end

function commands(args, var)
    unique_seqs = Set()
    str_input = read(`sed '/^[^>]/ s/X/-/g' $(var["input_path"])`, String)
    FASTA.Writer(open(var["output_file"], "w")) do writer
        FASTA.Reader(IOBuffer(str_input)) do reader
            for record in reader
                if !in(sequence(LongAminoAcidSeq, record), unique_seqs)
                    push!(unique_seqs, sequence(LongAminoAcidSeq, record))
                    write(writer, record)
                else
                    println("Removed duplicate sequence $(identifier(record)) on $(var["output_file"])")
                end
            end
        end
    end
    if length(unique_seqs) == 1
        rm(var["output_file"])
        println("Deleted singleton cluster: $(var["output_file"])")
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()