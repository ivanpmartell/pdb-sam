using ArgParse
using FASTX
using BioStructures
include("../common.jl")

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
            help = "Output directory. Cluster folders with mmcif files will be saved here. Ignore to use input directory"
        "--pdb_dir", "-p"
            help = "Download directory for pdb (structure) files"
            required = true
        "--write_seq", "-s"
            help = "Write mmcif sequences into new cluster fasta file"
            action = :store_true
        "--nested", "-n"
            help = "Alignment files are nested within directories"
            action = :store_true
        "--clean", "-c"
            help = "Clean (delete) downloaded PDB files"
            action = :store_true
    end
    return parse_args(s)
end

parsed_args = parse_commandline()

input_conditions(a,f) = has_extension(f, ".ala")

function preprocess!(args, var)
    var["pdb_struct_seqs"] = Set()
    var["records"] = Dict{String, FASTARecord}()
    FASTA.Reader(open(var["input_path"])) do reader
        for record in reader
            var["records"][identifier(record)] = record
            if args["nested"]
                input_dir_out_preprocess!(var, "$(identifier(record))"; fext=".cif")
            else
                directory_name = remove_ext(basename(var["input_path"]))
                input_dir_out_preprocess!(var, "$(identifier(record))"; fext=".cif", cdir=directory_name)
            end
        end
    end
end

function postprocess(args, var)
    if isone(length(var["pdb_struct_seqs"]))
        rm(dirname(var["abs_output_dir"]), recursive=true)
    end
end

function commands(args, var)
    current = remove_ext(basename(var["output_file"]))
    record = var["records"][current]
    id, chain = split(current,"_")
    downloaded_path = downloadpdb(id, dir=args["pdb_dir"], format=MMCIF)
    struc = read(downloaded_path, MMCIF)[chain]
    current_seq = LongAA(struc, standardselector, gaps=true)
    push!(var["pdb_struct_seqs"], current_seq)
    writemmcif(var["output_file"], struc)
    if args["write_seq"]
        FASTA.Writer(open(joinpath(var["abs_output_dir"], "cif_sequences.fa"), "a")) do writer
            write(writer, FASTA.Record("$(identifier(record)) $(description(record))", current_seq))
        end
    end
    if args["clean"]
        rm(downloaded_path)
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!, postprocess=postprocess, nested=parsed_args["nested"])
    return 0
end

main()