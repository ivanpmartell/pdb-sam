using FASTX
using BioSequences
using LogExpFunctions: xlogy, xlogx
using SparseArrays
using DelimitedFiles
using DataFrames

struct Mutation
    from::Char
    position::Int64
    to::Char
    proteins::Vector{String}
end

mutation_location(m::Mutation) = return m.position

function get_sequences_length(records::Dict{String, FASTX.FASTA.Record})
    len = length(sequence(last(first(records))))
    for i in eachindex(records)
        seq = sequence(records[i])
        if length(seq) !== len
            throw(ErrorException("Alignment file contains unequal length sequences"))
        end
    end
    return len
end

function get_sequences_length(records::Vector{FASTX.FASTA.Record})
    len = length(sequence(first(records)))
    for i in 2:length(records)
        seq = sequence(record[i])
        if length(seq) !== len
            throw(ErrorException("Alignment file contains unequal length sequences"))
        end
    end
    return len
end

function get_sequences_length(input_file::String)
    FASTA.Reader(open(input_file)) do reader
        for record in reader
            return length(sequence(record))
        end
    end
end

function fasta_vector(input_file)
    records = Vector{FASTX.FASTA.Record}()
    FASTA.Reader(open(input_file)) do reader
        records = collect(reader)
    end
    return records
end

function read_fasta(input_file)
    FASTA.Reader(open(input_file)) do reader
        return first(reader)
    end
end

function fasta_dict(input_file)
    records = Dict{String, FASTX.FASTA.Record}()
    FASTA.Reader(open(input_file)) do reader
        for record in reader
            records[identifier(record)] = record
        end
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

function max_in_column(m, column)
    v = view(m, :, column)
    return first(parentindices(v))[argmax(v)]
end

function calculate_frequency_matrix(records, aa_str)
    aa_alphabet_len = length(aa_str)
    cluster_seqs_len = length(sequence(LongAA, first(records)))
    freqs = zeros(Int, (aa_alphabet_len, cluster_seqs_len))
    for record in records
        seq = sequence(LongAA, record)
        for i in eachindex(seq)
            aa = seq[i]
            if !is_standard(aa)
                throw(ErrorException("Non-standard aminoacid found: $(aa)"))
            end
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
    cluster_seqs_len = length(sequence(LongAA, first(records)))
    matching_matrix = zeros(Int, (length(records), cluster_seqs_len))
    for (idx, record) in enumerate(records)
        seq = sequence(String, record)
        for i in eachindex(seq)
            if consensus_seq[i] == seq[i]
                matching_matrix[idx, i] += 1
            end
        end
    end
    matches = sum(matching_matrix, dims=2)
    consensus_idx = argmax(matches)[1]
    if matches[consensus_idx] < cluster_seqs_len
        println("No consensus match. Using closest sequence: $(identifier(records[consensus_idx]))")
    end
    return records[consensus_idx]
end

function read_mutations(mutation_file)
    mutations = Vector{Mutation}()
    open(mutation_file, "r") do reader
        for mutation in readlines(reader)
            pos_regex = r"(\w)(\d+)(\w) \[(.*)\]"
            from_str, pos_str, to_str, proteins = match(pos_regex, mutation).captures
            proteins_list = split(replace(proteins, r"[\" ]"=>""), ",")
            position = parse(Int64, pos_str)
            from = only(from_str)
            to = only(to_str)
            mut = Mutation(from, position, to, proteins_list)
            push!(mutations, mut)
        end
    end
    return mutations
end

function mutations_in_protein(mutations::Vector{Mutation}, protein)
    muts = Vector{Mutation}()
    for mut in mutations
        if protein in mut.proteins
            push!(muts, mut)
        end
    end
    return muts
end

function proteins_from_mutation(mutations::Vector{Mutation})
    return mutations.proteins
end

function read_consensus(consensus_file)
    data = readdlm(consensus_file, ' ')
    df = DataFrame(data, ["protein", "seq_type"])
    return df
end

function get_consensus(con_mut_df)
    return first(con_mut_df[con_mut_df.seq_type .== "consensus",:].protein)
end

function get_consensus_sequence(consensus_file, records)
    consensus_df = read_consensus(consensus_file)
    consensus_protein = get_consensus(consensus_df)
    return sequence(records[consensus_protein])
end

function pm1(a, side)
    return side == 'l' ? a - 1 : a + 1
end

function get_neighbor_ss(seq, pos, side, amt)
    starting_ss = seq[pos]
    current_ss = seq[pos]
    current_pos = pos
    for i in 1:amt
        while current_ss == starting_ss
            try
                current_pos = pm1(current_pos, side)
                current_ss = seq[current_pos]
            catch e
                break
            end
        end
        starting_ss = current_ss
    end
    return current_pos
end