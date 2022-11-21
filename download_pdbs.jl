using ArgParse
using Glob
using FASTX
#TODO: add console arguments and where to download the pdbs
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

#TODO: pdbtool to only leave the chain of interest

#TODO: make sure the variants are in pdb files

#TODO: automate pymol align, transparency of non-variant residues and highlight variants