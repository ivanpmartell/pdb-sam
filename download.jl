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
    end
    return parse_args(s)
end

function preprocess!(args, var)
    var["error_file"] = "$(var["output_file"]).err"
end

function commands(args, var)
    run(`wget -nc https://ftp.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt.gz`)
    run(`gunzip pdb_seqres.txt.gz`)
    run(`mv pdb_seqres.txt $(var["output_file"])`)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_single(parsed_args, commands; preprocess=preprocess!)
    return 0
end

main()