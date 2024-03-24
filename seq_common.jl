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

function ss_fasta_vector(input_dir, fext)
    records = Vector{FASTX.FASTA.Record}()
    for f in process_input(input_dir, 'f'; input_conditions=(a,x)->has_extension(x, fext), silence=true)
        FASTA.Reader(open(joinpath(input_dir, f))) do reader
            for record in reader
                push!(records, record)
            end
        end
    end
    return records
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

function ss_alphabet_str()
    return "CHEGITSB"
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

function ss_index(ss::Char, ss_str::String)
    return findfirst(ss, ss_str)
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

function calculate_ss_frequency_matrix(records, ss_str)
    ss_alphabet_len = length(ss_str)
    cluster_seqs_len = length(sequence(String, first(records)))
    freqs = zeros(Int, (ss_alphabet_len, cluster_seqs_len))
    for record in records
        seq = sequence(String, record)
        for i in eachindex(seq)
            ss = seq[i]
            if !(ss in ss_str)
                throw(ErrorException("Non-secondary structure found at $i: $(ss)"))
            end
            freqs[ss_index(ss, ss_str),i] += 1
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

function proteins_from_mutations(mutations::Vector{Mutation})
    proteins = Set()
    for mut in mutations
        for p in mut.proteins
            push!(proteins, p)
        end
    end
    return proteins
end

function read_vicinity_file(vicinity_file)
    return vec(readdlm(vicinity_file, ',', Int))
end

function read_mutations_vicinity_file(mut_vic_file)
    result = Dict{String, Vector{Int}}()
    for line in eachline(mut_vic_file)
        row = split(line, ' ', limit=2)
        data = filter(x -> !isspace(x), last(row))
        vicinity_str = split(strip(data,['[', ']']),',')
        result[first(row)] = parse.(Int, vicinity_str)
    end
    return result
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

function mask_non_consecutive(seq, indices::Vector{Int})
    splits = split_non_consecutive(indices)
    return join([seq[splits[i]] for i in eachindex(splits)], 'X')
end

function split_non_consecutive(indices, step=1)
    split_result = []
    split_idx = vcat(0, findall(==(1), diff(indices) .!= step), length(indices))

    for i in 1:length(split_idx)-1
        push!(split_result, indices[split_idx[i]+1:split_idx[i+1]])
    end
    return split_result
end

function get_non_locality(indices, seqs_length)
    non_local = collect(1:seqs_length)
    deleteat!(non_local, indices)
    return non_local
end

function read_metrics(metrics, sov_refine_output)
    results = Dict{String, Float32}()
    for line in split(sov_refine_output, '\n')
        line_split = split(line, '\t')
        if first(line_split) in metrics
            results[first(line_split)] = parse(Float32, last(line_split))
        end
    end
    return results
end

function get_metrics(sov_refine_path, metrics, file_ref, file_pred)
    cmd = pipeline(`$(sov_refine_path) $(file_ref) $(file_pred)`, stderr=devnull)
    output = read(cmd, String)
    return read_metrics(metrics, output)
end

function write_temp(name, seq)
    tmp_file = tempname()
    FASTA.Writer(open(tmp_file, "w")) do writer
        write(writer, FASTA.Record(name, seq))
    end
    return tmp_file
end

function create_temp_files(use_mask, indices, ref_sequence, pred_sequence, protein_name)
    tmp_ref = ""
    tmp_pred = ""
    if use_mask
        ref_masked = mask_non_consecutive(ref_sequence, indices)
        tmp_ref = write_temp(protein_name, ref_masked)
        pred_masked = mask_non_consecutive(pred_sequence, indices)
        tmp_pred = write_temp(protein_name, pred_masked)
    else
        tmp_ref = write_temp(protein_name, ref_sequence[indices])
        tmp_pred = write_temp(protein_name, pred_sequence[indices])
    end
    return tmp_ref, tmp_pred
end
