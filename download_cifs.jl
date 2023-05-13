using ArgParse
using Glob
using FASTX
using BioStructures
using ProgressBars

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cleaned cluster alignment files should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cluster folders with mmcif files will be saved here. Ignore to use input directory"
        "--write_seq", "-s"
            help = "Write mmcif sequences into new cluster fasta file"
            action = :store_true
        "--write_dssp", "-d"
            help = "Write dssp output for each mmcif (Requires mkdssp installed)"
            action = :store_true
        "--nested", "-n"
            help = "Alignment files are nested within directories"
            action = :store_true
        "--clean", "-c"
            help = "Clean (delete) downloaded temporary files"
            action = :store_true
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
#Change to nested paths
if !parsed_args["nested"]
    for f in glob("*.ala", parsed_args["input"])
        cluster = chop(last(split(f, "/")),tail=7)
        cluster_path = joinpath(parsed_args["output"], cluster)
        mkpath(cluster_path)
        pdb_struct_seqs = Set()
        FASTA.Reader(open(f)) do reader
            for record in reader
                current = identifier(record)
                file_name = joinpath(cluster_path, current)
                id, chain = split(current,"_")
                downloaded_path = downloadpdb(id, dir=cluster_path, format=MMCIF)
                if parse_args["write_dssp"]
                    run(`mkdssp $(downloaded_path) $(file_name).mmcif`)
                end
                struc = read(downloaded_path, MMCIF)[chain]
                current_seq = LongAminoAcidSeq(struc, standardselector, gaps=true)
                push!(pdb_struct_seqs, current_seq)
                if !isfile("$(file_out).cif")
                    writemmcif("$(file_name).cif", struc)
                end
                if parsed_args["write_seq"]
                    FASTA.Writer(open(joinpath(cluster_path, "cif_sequences.fa"), "a")) do writer
                        write(writer, FASTA.Record(identifier(record), description(record), current_seq))
                    end
                end
                if parsed_args["clean"]
                    rm(downloaded_path)
                end
            end
        end
        if length(pdb_struct_seqs) == 1
            rm(cluster_path, recursive=true)
            continue
        end
    end
else
    for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
        for f in files
            if endswith(f, ".ala")
                f_path = joinpath(root, f)
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                pdb_struct_seqs = Set()
                FASTA.Reader(open(f_path)) do reader
                    for record in reader
                        current = identifier(record)
                        file_out = joinpath(f_out_path, current)
                        id, chain = split(current,"_")
                        downloaded_path = downloadpdb(id, dir=f_out_path, format=MMCIF)
                        if parsed_args["write_dssp"]
                            if !isfile("$(file_out).mmcif")
                                run(`mkdssp $(downloaded_path) $(file_out).mmcif`)
                            end
                        end
                        struc = read(downloaded_path, MMCIF)[chain]
                        current_seq = LongAminoAcidSeq(struc, standardselector, gaps=true)
                        push!(pdb_struct_seqs, current_seq)
                        if !isfile("$(file_out).cif")
                            writemmcif("$(file_out).cif", struc)
                        end
                        if parsed_args["write_seq"]
                            FASTA.Writer(open(joinpath(f_out_path, "cif_sequences.fa"), "w")) do writer
                                write(writer, FASTA.Record(identifier(record), description(record), current_seq))
                            end
                        end
                        if parsed_args["clean"]
                            rm(downloaded_path)
                        end
                    end
                end
                if length(pdb_struct_seqs) == 1
                    rm(f_out_path, recursive=true)
                    continue
                end
            end
        end
    end
end