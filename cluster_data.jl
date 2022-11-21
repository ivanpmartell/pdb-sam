using ArgParse

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input file (fasta format)"
            required = true
        "--output", "-o"
            help = "Output file (fasta format)"
            required = true
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
run(`cd-hit -i $(parsed_args["input"]) -o $(parsed_args["output"]) -c 0.99 -s 0.9`)

#TODO: Add mmseqs2 option