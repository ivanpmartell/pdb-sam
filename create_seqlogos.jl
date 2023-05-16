using ArgParse
using ProgressBars
using Glob
using FASTX
using BioSequences
using LogExpFunctions: xlogx
using PyCall
using Pandas

#TODO: Modify to work with cleaned clusters and clean cifs
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cleaned cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cluster folders with sequence logo files will be saved here. Ignore to use input directory"
        "--nested", "-n"
            action = :store_true
    end
    return parse_args(s)
end

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
    i = 1
    for aa in alphabet(AminoAcid)
        if !is_standard(aa)
            continue
        end
        aa_str = string(aa)
        alphabet_string *= aa_str
    end
    return alphabet_string
end

function aa_index(aa::AminoAcid, aa_len, i)
    return reinterpret(UInt8, aa) + aa_len*(i-1) + 1
end

function seqlogo_matrix(p::AbstractMatrix)
    w = p ./ sum(p; dims=1)
    H = -xlogx.(w)
    return transpose(H)
end

py"""
def save_seqlogo(df, file_name, window_size):
    import logomaker
    import matplotlib.pyplot as plt
    from math import ceil
    for i in range(ceil(len(df)/window_size)):
        current_idx = i * window_size
        current_df = df.iloc[current_idx:current_idx+window_size]
        if not current_df.max().any():
            continue
        msaSeqLogo = logomaker.Logo(current_df,
                        font_name='Verdana',
                        color_scheme='NajafabadiEtAl2017',
                        figsize=(20, 3))
        msaSeqLogo.ax.set_ylim(0, 1)
        msaSeqLogo.ax.set_yticks([0, 0.25, .5, 0.75, 1])
        msaSeqLogo.fig.savefig(f"{file_name}_{current_idx}-{current_idx+window_size}.png")
        plt.close(msaSeqLogo.fig)
"""
pysave_seqlogo = py"save_seqlogo"

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
aa_str = aa_alphabet_str()
alphabet_len = length(aa_str)

if !parsed_args["nested"]
    for f in ProgressBar(glob("*.ala", parsed_args["input"]))
        cluster = splitext(basename(f))[1]
        cluster_path = joinpath(parsed_args["output"], cluster)
        mkpath(cluster_path)
        seqs_len = get_sequences_length(f)
        freqs = zeros(Int, (alphabet_len, seqs_len))
        FASTA.Reader(open(f)) do reader
            for record in reader
                seq = sequence(LongAminoAcidSeq, record)
                for i in eachindex(seq)
                    aa = seq[i]
                    if is_standard(aa)
                        freqs[aa_index(aa, alphabet_len, i)] += 1
                    end
                end
            end
        end
        seqlogo_mat = seqlogo_matrix(freqs)
        seqlogo_df = DataFrame(seqlogo_mat; columns=split(aa_str,""))
        seqlogo_df = fillna(seqlogo_df, 0)
        pysave_seqlogo(seqlogo_df, "$(cluster_path)/seqlogo", 100)
        try
            rm(cluster_path)
        catch e
            continue
        end
    end
else
    for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
        for f in files
            if endswith(f, ".ala")
                f_path = joinpath(root,f)
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                f_out_path = joinpath(f_out_path, "seqlogos/")
                mkpath(f_out_path)
                seqs_len = get_sequences_length(f_path)
                freqs = zeros(Int, (alphabet_len, seqs_len))
                FASTA.Reader(open(f_path)) do reader
                    for record in reader
                        seq = sequence(LongAminoAcidSeq, record)
                        for i in eachindex(seq)
                            aa = seq[i]
                            if is_standard(aa)
                                freqs[aa_index(aa, alphabet_len, i)] += 1
                            end
                        end
                    end
                end
                seqlogo_mat = seqlogo_matrix(freqs)
                seqlogo_df = DataFrame(seqlogo_mat; columns=split(aa_str,""))
                seqlogo_df = fillna(seqlogo_df, 0)
                seqlogos_path = joinpath(f_out_path, "logo")
                pysave_seqlogo(seqlogo_df, seqlogos_path, 100)
            end
        end
    end
end