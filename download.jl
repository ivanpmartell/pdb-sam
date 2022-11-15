using ArgParse

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "output"
            help = "Output file (fasta format)"
            required = true
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
out_file = parsed_args["output"]
mkpath(dirname(out_file))
run(`wget -nc https://ftp.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt.gz`)
run(`gunzip pdb_seqres.txt.gz`)
run(`mv pdb_seqres.txt $(out_file)`)