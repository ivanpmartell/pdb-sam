using ArgParse
using Glob
using FASTX
using BioStructures

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cleaned cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cluster folders with pdb files will be saved here. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
for f in glob("*.ala", parsed_args["input"])
    cluster = chop(last(split(f, "/")),tail=7)
    cluster_path = joinpath(parsed_args["output"], cluster)
    mkpath(cluster_path)
    pdb_struct_seqs = Set()
    FASTA.Writer(open(joinpath(cluster_path, "cif_sequences.fa"), "w")) do writer
        FASTA.Reader(open(f)) do reader
            for record in reader
                current = identifier(record)
                id, chain = split(current,"_")
                downloaded_path = downloadpdb(id, dir=cluster_path, format=MMCIF)
                struc = read(downloaded_path, MMCIF)[chain]
                current_seq = LongAminoAcidSeq(struc, standardselector, gaps=true)
                push!(pdb_struct_seqs, current_seq)
                writemmcif("$(joinpath(cluster_path, current)).cif", struc)
                write(writer, FASTA.Record(identifier(record), description(record), current_seq))
                rm(downloaded_path)
            end
        end
    end
    if length(pdb_struct_seqs) == 1
        rm(cluster_path, recursive=true)
        continue
    end
end