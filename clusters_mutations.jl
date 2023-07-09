using ArgParse
using ProgressBars
using FASTX
using BioSequences
using LogExpFunctions: xlogy
using SparseArrays

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Clusters with sequence alignments required"
            required = true
        "--output", "-o"
            help = "Output directory. Mutations file for each cluster will be saved here. Ignore to use input directory"
        "--extension", "-e"
            help = "Alignment file extension. Default is .fa.ala"
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

function info_matrix(p::AbstractMatrix)
    w = p ./ sum(p; dims=1)
    H = -xlogy.(w,1 .- w)
    return transpose(H)
end

function findmin_view(x,b)
    v = view(x,b)
    return first(parentindices(v))[argmax(v)]
end

function extract_mutations(matrix, path)
    sparse_mat = sparse(matrix)
    mut_pos, mut_aa, mut_val = findnz(sparse_mat)
    all_positions = sort(collect(Set(mut_pos)))
    for position in all_positions
        indices = findall(==(position), mut_pos)
        others = Set(indices)
        consensus = findmin_view(mut_val, indices)
        delete!(others, consensus)
        for i in others
            open(path, "a") do file
                println(file, aa_str[mut_aa[consensus]], position, aa_str[mut_aa[i]])
            end
        end
    end
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if isnothing(parsed_args["extension"])
    parsed_args["extension"] = ".fa.ala"
end
aa_str = aa_alphabet_str()
alphabet_len = length(aa_str)

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if endswith(f, parsed_args["extension"])
            f_noext, f_ext = splitext(f)
            f_path = joinpath(root,f)
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_path = joinpath(f_out_dir, "$(f_noext).mut")
            if !isfile(f_out_path)
                mkpath(f_out_dir)
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
                matrix = info_matrix(freqs)
                replace!(matrix, Inf=>0)
                extract_mutations(matrix, f_out_path)
            end
        end
    end
end