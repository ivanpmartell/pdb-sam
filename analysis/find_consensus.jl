#TODO
aa_str = aa_alphabet_str()
records = collect_fasta(var["input_path"])
freqs = calculate_frequency_matrix(records, aa_str)
consensus_seq = calculate_consensus_sequence(freqs, aa_str)
consensus = match_consensus(records, consensus_seq)
#identifier(consensus) is consensus, rest are mutated