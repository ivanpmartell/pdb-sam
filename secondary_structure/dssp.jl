using ArgParse
include("../common.jl")
# Requires mkdssp installed
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory containing mmcif files downloaded from PDB"
            required = true
        "--extension", "-e"
            help = "Extension for input files"
            default = ".mmcif"
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

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

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".mmcif")
end

function commands(args, var)
    run(`mkdssp $(var["input_path"]) $(var["output_file"])`)
    fix_dssp_formatting_errors(var["input_path"], var["output_file"])
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()