using ArgParse
include("./common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--output", "-o"
            help = "Output file (fasta format)"
            required = true
        "--input", "-i"
            help = "Input url to download PDB sequences"
            default = "https://files.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt.gz"
            required = false
    end
    return parse_args(s)
end

function preprocess!(args, var)
    file_preprocess!(var)
end

function commands(args, var)
    run(`wget -nc $(var["input_path"])`)
    run(`gunzip pdb_seqres.txt.gz`)
    run(`mv pdb_seqres.txt $(var["output_file"])`)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_single(parsed_args, commands; preprocess=preprocess!, runtime_unit="sec")
    return 0
end

main()