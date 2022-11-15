using ArgParse
using ProgressBars
using Glob
using FASTX
using BioSequences
using LogExpFunctions: xlogx
using PyCall
using Pandas

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cleaned cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cluster folders with sequence logo files will be saved here. Ignore to use input directory"
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

function filtered_aa_alphabet()
    filtered_abet = Dict{AminoAcid, Int64}()
    alphabet_string = ""
    i = 1
    for aa in alphabet(AminoAcid)
        if aa === AA_O || aa === AA_U || aa === AA_B || aa === AA_J || aa === AA_Z || aa === AA_X || aa === AA_Term || aa === AA_Gap
            continue
        end
        filtered_abet[aa] = i
        aa_str = string(aa)
        alphabet_string *= aa_str
        i += 1
    end
    return (filtered_abet, alphabet_string)
end

function seqlogo_matrix(p::AbstractMatrix)
    w = p ./ sum(p; dims=1)
    H = -xlogx.(w)
    return transpose(H)
end

py"""
def save_seqlogo(df, file_name, window_size):
    import logomaker
    import matplotlib
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
    matplotlib.pyplot.close()
"""
pysave_seqlogo = py"save_seqlogo"

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
for f in ProgressBar(glob("*.ala", parsed_args["input"]))
    aa_alphabet, aa_str = filtered_aa_alphabet()
    seqs_len = get_sequences_length(f)
    freqs = zeros(Int64, (length(aa_alphabet), seqs_len))
    FASTA.Reader(open(f)) do reader
        for record in reader
            seq = sequence(LongAA, record)
            for i in eachindex(seq)
                try
                    freqs[aa_alphabet[seq[i]], i] += 1
                catch e
                    continue
                end
            end
        end
    end
    seqlogo_mat = seqlogo_matrix(freqs)
    seqlogo_df = DataFrame(seqlogo_mat; columns=split(aa_str,""))
    cluster = chop(last(split(f, "/")),tail=7)
    cluster_path = joinpath(parsed_args["output"], cluster)
    mkpath(cluster_path)
    pysave_seqlogo(seqlogo_df, "$(cluster_path)/seqlogo", 100)
end