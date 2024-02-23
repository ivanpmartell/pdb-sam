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

function collect_fasta(input_file)
    records = Vector{FASTX.FASTA.Record}()
    FASTA.Reader(open(input_file)) do reader
        records = collect(reader)
    end
    return records
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

function max_in_column(m, column)
    v = view(m, :, column)
    return first(parentindices(v))[argmax(v)]
end

function calculate_frequency_matrix(records, aa_str)
    aa_alphabet_len = length(aa_str)
    freqs = zeros(Int, (aa_alphabet_len, cluster_seqs_len))
    for record in records
        seq = sequence(LongAA, record)
        for i in eachindex(seq)
            aa = seq[i]
            freqs[aa_index(aa, aa_alphabet_len, i)] += 1
        end
    end
    return freqs
end

function calculate_consensus_sequence(frequency_matrix, aa_str)
    consensus = ""
    for i in 1:size(frequency_matrix, 2)
        aa_idx = max_in_column(frequency_matrix, i)
        consensus *= aa_str[aa_idx]
    end
    return consensus
end

function match_consensus(records, consensus_seq)
    matching_matrix = zeros(Int, (length(records), cluster_seqs_len))
    for idx, record in enumerate(records)
        seq = sequence(LongAA, record)
        for i in eachindex(seq)
            if consensus_seq[i] == seq[i]
                matching_matrix[idx, i] += 1
            end
        end
    end
    consensus_idx = first(argmax(sum(matching_matrix, dims=2)))
    return records[consensus_idx]
end
