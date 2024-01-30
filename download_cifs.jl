using ArgParse
using FASTX
using BioStructures
using ProgressBars
include("./common.jl")
#TODO
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

function fix_dssp_formatting_errors(cif_path, dssp_out_path)
    fix_list = Dict{Int64, Dict{String, String}}()
    lines_to_fix = Dict{Int64, String}()
    for (num, line) in enumerate(eachline(cif_path))
        if contains(line, '\"')
            lines_to_fix[num] = line
        end
    end
    if isempty(lines_to_fix)
        return nothing
    end
    for (num, line) in lines_to_fix
        fix_list[num] = Dict{String, String}()
        quotes_regex = r"\"([^\"]*)\""
        for regex_match in eachmatch(quotes_regex, line)
            captured_match = regex_match.captures[1]
            fixed_match = "\"$(captured_match)\""
            fix_list[num][captured_match] = fixed_match
        end
    end
    (tmppath, tmpio) = mktemp()
    for line in eachline(dssp_out_path)
        if contains(line, '\'')
            for (line_num, fixes) in fix_list
                clean_line_to_fix = replace(lines_to_fix[line_num], " "=>"",  "\""=>"", "?"=>"")
                clean_line = replace(line, " "=>"", "?"=>"")
                if startswith(clean_line_to_fix, clean_line) || startswith(clean_line, clean_line_to_fix)
                    for (unfixed, fix) in fixes
                        line = replace(line, unfixed=>fix)
                    end
                    delete!(fix_list, line_num)
                    break
                end
            end
        end
        println(tmpio, line)
    end
    close(tmpio)
    mv(tmppath, dssp_out_path, force=true)
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
                    dssp_out_file = "$(file_name).mmcif"
                    if !isfile(dssp_out_file)
                        run(`mkdssp $(downloaded_path) $(dssp_out_file)`)
                        fix_dssp_formatting_errors(downloaded_path, dssp_out_file)
                    end
                end
                struc = read(downloaded_path, MMCIF)[chain]
                current_seq = LongAminoAcidSeq(struc, standardselector, gaps=true)
                push!(pdb_struct_seqs, current_seq)
                if !isfile("$(file_name).cif")
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
            if has_extension(f, ".ala")
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
                            dssp_out_file = "$(file_out).mmcif"
                            if !isfile(dssp_out_file)
                                run(`mkdssp $(downloaded_path) $(dssp_out_file)`)
                                fix_dssp_formatting_errors(downloaded_path, dssp_out_file)
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