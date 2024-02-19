using ArgParse
using FASTX
using BioSequences
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--separate", "-s"
            help = "Choose this flag if fasta files should be separated into one record per file"
            action = :store_true
    end
    return parse_args(s)
end

function extract_len(str)
    regex = r"length:(\d+)\s"
    regex_match = match(regex, str)
    if regex_match !== nothing
        return parse(Int, regex_match[1])
    else
        return nothing
    end
end

function separate_records(script_args, in_path)
    num_records = 0
    full_len_records = 0
    record_list = Vector{String}()
    FASTA.Reader(open(in_path)) do reader
        for record in reader
            num_records += 1
            out_file = joinpath(dirname(in_path), "$(identifier(record)).fa")
            seq = sequence(LongAA, record)
            seq_len = count(iscertain, seq)
            #seq_len = length(seq)
            rec_len = extract_len(description(record))
            if seq_len === rec_len
                if count(!iscertain, seq) === 0 
                    full_len_records += 1
                end
            end
            if script_args["separate"]
                push!(record_list, out_file)
                FASTA.Writer(open(out_file, "w")) do writer
                    write(writer, record)
                end
            end
        end
    end
    if num_records > 0
        if full_len_records == num_records
            if !isnothing(script_args["output"])
                for record in record_list
                    f_out_path = dirname(var["output_file"])
                    out_file = joinpath(f_out_path, "$(basename(record))")
                    cp(record, out_file)
                    record_cif = "$(remove_ext(record)).cif"
                    out_cif = joinpath(f_out_path, "$(basename(record_cif))")
                    cp(record_cif, out_cif)
                end
            end
            return true
        else
            return false
        end
    else
        return false
    end
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_basename"])
end

function commands(args, var)
    if separate_records(args, var["input_path"])
        cp(var["input_path"], var["output_file"], force=true)
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!, runtime_unit="sec")
    return 0
end

main()