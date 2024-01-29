using FASTX
using BioSequences
using LogExpFunctions: xlogy, xlogx
using SparseArrays

function get_sequences_length(input_file)
    FASTA.Reader(open(input_file)) do reader
        for record in reader
            return length(sequence(record))
        end
    end
end

function is_standard(aa::AminoAcid)
    return AA_A ≤ aa ≤ AA_V
end

function aa_alphabet_str()
    alphabet_string = ""
    for aa in alphabet(AminoAcid)
        if !is_standard(aa)
            continue
        end
        alphabet_string *= string(aa)
    end
    return alphabet_string
end

function aa_index(aa::AminoAcid, aa_len, i)
    return reinterpret(UInt8, aa) + aa_len*(i-1) + 1
end

function info_matrix(p::AbstractMatrix)
    w = p ./ sum(p; dims=1)
    H = -xlogy.(w,1 .- w)
    return transpose(H)
end

function seqlogo_matrix(p::AbstractMatrix)
    w = p ./ sum(p; dims=1)
    H = -xlogx.(w)
    return transpose(H)
end

function findmin_view(x,b)
    v = view(x,b)
    return first(parentindices(v))[argmax(v)]
end
