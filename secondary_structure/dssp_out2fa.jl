using ArgParse
using DelimitedFiles
using DataFrames
using FASTX
using BioSequences
using BioStructures
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Directory with clusters containing DSSP assignments"
            required = true
        "--extension", "-e"
            help = "DSSP output files' extension. Default .mmcif"
            default = ".mmcif"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
        "--output_extension", "-x"
            default = ".ssfa"
        "--fix", "-f"
            help = "Fix DSSP output files in case of quoting formatting error"
            action = :store_true
        "--predicted", "-p"
            help = "Use for predicted tertiary structures"
            action = :store_true
        "--structure_order", "-s"
            help = "Use aminoacid structure ordering from DSSP output"
            action = :store_true
    end
    return parse_args(s)
end

function parse_dssp_mmcif(results_path, ch)
    mmcif_dict = MMCIFDict(results_path)
    dssp_data = "_struct_conf"
    dssp_mmcif_header = ["conf_type_id", "id",
        "beg_auth_comp_id", "beg_auth_asym_id", "beg_label_seq_id",
        "end_auth_comp_id", "end_auth_asym_id", "end_label_seq_id",
        "beg_auth_seq_id", "end_auth_seq_id"]
    dssp_readable_header = ["2dstruc", "2dstruc_id",
        "aa_start", "chain_start", "seq_start",
        "aa_end", "chain_end", "seq_end",
        "struc_start", "struc_end"]
    column_headers = string.(dssp_data, ".", dssp_mmcif_header)
    assignments = Matrix{Any}(undef, length(mmcif_dict[first(column_headers)]), length(column_headers))
    for (i, header) in enumerate(column_headers)
        assignments[:, i] = mmcif_dict[header]
    end
    #Obtain sequence
    struc = MolecularStructure(mmcif_dict)
    first_residue = first(resids(struc[ch]))
    start_residue = resnumber(residues(struc[ch])[first_residue])
    sequence = LongAA(struc[ch], standardselector, gaps=true)
    df = DataFrame(assignments, dssp_readable_header)
    filter!(:chain_end => ==(ch), df)
    df.seq_start = parse.(Int64, df.seq_start)
    df.seq_end = parse.(Int64, df.seq_end)
    df.struc_start = parse.(Int64, df.struc_start)
    df.struc_end = parse.(Int64, df.struc_end)
    return (df, sequence, start_residue)
end

function fix_isolated_bridge(str)
    assignment = str
    for i in eachindex(str)
        if str[i] == 'E'
            isolated = 2
            try
                if str[i-1] !== 'E'
                    isolated -= 1
                end
            catch e
                nothing
            end
            try
                if str[i+1] !== 'E'
                    isolated -= 1
                end
            catch e
                nothing
            end
            if isolated == 0
                assignment = str_sub(assignment, 'B', i, i)
            end
        end
    end
    return assignment
end

function str_sub(str::String, replacement::Char, istart::Int, iend::Int)
    change = repeat(replacement, iend - istart + 1)
    return SubString(str, firstindex(str), istart-1) * change * SubString(str, iend+1, lastindex(str))
end

function normalize_dssp_ouput(df, seq_len, start_resnum, struc_order)
    assignment = repeat('C', seq_len)
    dssp_dict = Dict("HELX_LH_PP_P" => 'C', #Not in 8-class format
                    "HELX_RH_AL_P" => 'H',
                    "STRN" => 'E', #Almost never B (isolated beta-bridge), B is assigned later
                    "HELX_RH_3T_P" => 'G',
                    "HELX_RH_PI_P" => 'I',
                    "TURN_TY1_P" => 'T',
                    "BEND" => 'S')
    for row in eachrow(df)
        sub_start = sub_end = 0
        if struc_order
            sub_start = row["struc_start"] - start_resnum + 1
            sub_end = row["struc_end"] - start_resnum + 1
        else
            sub_start = row["seq_start"]
            sub_end = row["seq_end"]
        end
        assignment = str_sub(assignment, dssp_dict[row["2dstruc"]], sub_start, sub_end)
    end
    #Change E to B if isolated (Must make sure it makes sense)
    assignment = fix_isolated_bridge(assignment)
    return assignment
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

function convert_dssp(f_noext, f_path, f_out_path, seq_file, predicted, struc_order, retry)
    id_chain_split = split(f_noext, "_")
    id = ch = "";
    if (length(id_chain_split) < 2)
        id = first(id_chain_split)
    else
        id, ch = id_chain_split
    end
    tool = "dssp"
    if predicted
        ch = "A"
        tool = last(split(dirname(f_path), '/'))
    end
    try
        assign_df, assign_seq, start_resnum = parse_dssp_mmcif(f_path, ch)
        if isempty(assign_df)
            throw(ErrorException("Dataframe parsing error"))
        end
        if isfile(seq_file)
            reader = FASTA.Reader(open(seq_file))
            seq_rec = first(reader); close(reader);
            if length(sequence(seq_rec)) !== length(assign_seq)
                throw(ErrorException("Sequence lengths mismatch"))
            end
        end
        assignment = normalize_dssp_ouput(assign_df, length(assign_seq), start_resnum, struc_order)
        #Write ss assignment file
        FASTA.Writer(open(f_out_path, "w")) do writer
            write(writer, FASTA.Record("$(f_noext)_$(tool)", assignment))
        end
    catch e
        if isa(e, ArgumentError)
            root = dirname(f_path)
            cif_path = joinpath(root, "$(uppercase(id)).cif")
            if retry
                if isfile(cif_path)
                    if startswith(e.msg, "Opening quote")
                        fix_dssp_formatting_errors(cif_path, f_path)
                        convert_dssp(f_noext, f_path, f_out_path, seq_file, predicted, struc_order, false)
                    else
                        println("Could not fix dssp output format error: $(e)")
                        rethrow(e)
                    end
                else
                    println("Could not find original cif file: $(cif_path)")
                end
            else
                println("Did not attempt to fix dssp format errors. Use -f if needed")
                rethrow(e)
            end
        else
            rethrow(e)
        end
    end
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=args["output_extension"])
end

function commands(args, var)
    sequence_file = joinpath(var["abs_input_dir"], "$(var["input_noext"]).fa")
    convert_dssp(var["input_noext"], var["input_path"], var["output_file"], sequence_file, args["predicted"], args["structure_order"], args["fix"])
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()