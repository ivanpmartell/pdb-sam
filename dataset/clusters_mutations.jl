using ArgParse
using ProgressBars
using FASTX
using BioSequences
using LogExpFunctions: xlogy
using SparseArrays
include("../common.jl")
include("../seq_common.jl")
#SCRIPT obsolete. Use analysis/mutations.jl
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Clusters with sequence alignments required"
            required = true
        "--output", "-o"
            help = "Output directory. Mutations file for each cluster will be saved here. Ignore to use input directory"
        "--extension", "-e"
            help = "Alignment file extension. Default is .fa.ala"
            default = ".fa.ala"
    end
    return parse_args(s)
end

function extract_mutations(matrix, var)
    sparse_mat = sparse(matrix)
    mut_pos, mut_aa, mut_val = findnz(sparse_mat)
    all_positions = sort(collect(Set(mut_pos)))
    for position in all_positions
        indices = findall(==(position), mut_pos)
        others = Set(indices)
        consensus = findmin_view(mut_val, indices)
        delete!(others, consensus)
        for i in others
            open(var["output_file"], "a") do file
                println(file, var["aminoacid_alphabet"][mut_aa[consensus]], position, var["aminoacid_alphabet"][mut_aa[i]])
            end
        end
    end
end

input_conditions(a,f) = has_extension(f, parsed_args["extension"])

function initialize!(args, var)
    var["aminoacid_alphabet"] = aa_alphabet_str()
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".mut")
end

function commands(args, var)
    alphabet_len = length(var["aminoacid_alphabet"])
    seqs_len = get_sequences_length(var["input_path"])
    freqs = zeros(Int, (alphabet_len, seqs_len))
    FASTA.Reader(open(var["input_path"])) do reader
        for record in reader
            seq = sequence(LongAA, record)
            for i in eachindex(seq)
                aa = seq[i]
                if is_standard(aa)
                    freqs[aa_index(aa, alphabet_len, i)] += 1
                end
            end
        end
    end
    matrix = info_matrix(freqs)
    replace!(matrix, Inf=>0)
    extract_mutations(matrix, var)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()