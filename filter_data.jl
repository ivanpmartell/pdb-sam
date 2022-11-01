using FASTX
using BioSequences

seqs = Set()
onlyX = Regex("^X+\$")
#Removes non-protein sequences and identical sequences
FASTA.Writer(open("pdb_filtered.fa", "w")) do writer
    FASTA.Reader(open("pdb_seqres.txt")) do reader
        try
            for record in reader
                if occursin("mol:protein", description(record)) &&
                        !in(sequence(LongAminoAcidSeq, record), seqs) &&
                        isnothing(match(onlyX, sequence(String, record)))
                    write(writer, record)
                    push!(seqs, sequence(LongAminoAcidSeq, record))
                end
            end
        catch e
            println("Skipping record (malformed)")
        end
    end
end