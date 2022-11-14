using Glob
using FASTX

for f in glob("*.ala","alignments")
    f_path = "$(SubString(f,1,lastindex(f)-7))"
    FASTA.Reader(open(f)) do reader
        for record in reader
            current = identifier(record)
            id, chain = split(current,"_")
            download("https://files.rcsb.org/view/$(id).pdb", "$(f_path)/$(id).pdb")
        end
    end
end