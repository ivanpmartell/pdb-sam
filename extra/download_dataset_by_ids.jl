using ArgParse
using FASTX
using BioSequences
using BioStructures
using DelimitedFiles
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input file containing PDB identifiers"
            required = true
        "--separator", "-r"
            help = "Separator for the input file. Comma (,) by default"
            default = ','
            required = false
        "--output", "-o"
            help = "Output directory. Cluster folders with mmcif files will be saved here. Ignore to use input directory"
        "--pdb_dir", "-p"
            help = "Download directory for pdb (structure) files"
            required = true
        "--write_seq", "-s"
            help = "Write mmcif sequences into new cluster fasta file"
            action = :store_true
        "--clean", "-c"
            help = "Clean (delete) downloaded PDB files"
            action = :store_true
    end
    return parse_args(s)
end

parsed_args = parse_commandline()

function preprocess!(args, var)
    data = readdlm(var["input_path"], ',', String)
    for pdb_id in data
        input_dir_out_preprocess!(var, pdb_id; fext=".cif")
    end
end

function is_clean(seq)
    dirty_count = 0
    for l in eachindex(seq)
        if seq[l] == AA_Gap
            dirty_count += 1
        elseif seq[l] == AA_X
            dirty_count += 1
        end
    end
    return dirty_count == 0
end

function occursinset(seq::LongAA, seq_set::Set{LongAA})
    for s in seq_set
        if seq == s
            return true
        end
    end
    return false     
end

function commands(args, var)
    current = remove_ext(basename(var["output_file"]))
    id_chain_split = split(current, "_")
    id = chain = "";
    if (length(id_chain_split) < 2)
        id = first(id_chain_split)
    else
        id, chain = id_chain_split
    end
    downloaded_path = downloadpdb(id, dir=args["pdb_dir"], format=MMCIF)
    struc = read(downloaded_path, MMCIF)
    struc_chains = Dict()
    if (isempty(chain))
        struc_chains = chains(struc)
    else
        struc_chains[chain] = struc[chain]
    end
    good_chains = Set{LongAA}()
    for (chain, struc_chain) in struc_chains
        current_seq = LongAA(struc_chain, standardselector, gaps=true)
        if !is_clean(current_seq) || length(current_seq) < 50
            continue
        end
        if occursinset(current_seq, good_chains)
            continue
        end
        push!(good_chains, current_seq)
        writemmcif(var["output_file"], struc_chain)
        if args["write_seq"]
            protein_rec = "$(id)_$(chain)"
            FASTA.Writer(open(joinpath(var["abs_output_dir"], "$(protein_rec).fa"), "w")) do writer
                write(writer, FASTA.Record(protein_rec, current_seq))
            end
        end
        if args["clean"]
            rm(downloaded_path)
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_single(parsed_args, commands; preprocess=preprocess!, runtime_unit="sec")
    return 0
end

main()