using ArgParse
using FASTX
using BioSequences
using PyCall
using Pandas
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cleaned cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cluster folders with sequence logo files will be saved here. Ignore to use input directory"
        "--extension", "-e"
            help = "Alignment file extension. Default is .ala"
            default = ".ala"
    end
    return parse_args(s)
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

input_conditions(a,f) = has_extension(f, parsed_args["extension"])

function initialize!(args, var)
    var["aminoacid_alphabet"] = aa_alphabet_str()
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "logo"; cdir="seqlogos/")
end

function commands(args, var)
    seqs_len = get_sequences_length(var["input_path"])
    freqs = zeros(Int, (length(var["aminoacid_alphabet"]), seqs_len))
    FASTA.Reader(open(var["input_path"])) do reader
        for record in reader
            seq = sequence(LongAA, record)
            for i in eachindex(seq)
                aa = seq[i]
                if is_standard(aa)
                    freqs[aa_index(aa, length(var["aminoacid_alphabet"]), i) += 1
                end
            end
        end
    end
    seqlogo_mat = seqlogo_matrix(freqs)
    seqlogo_df = DataFrame(seqlogo_mat; columns=split(var["aminoacid_alphabet"],""))
    seqlogo_df = fillna(seqlogo_df, 0)
    pysave_seqlogo(seqlogo_df, var["output_file"], 100)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()