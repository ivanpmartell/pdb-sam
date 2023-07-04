using ArgParse
using Glob
using ProgressBars
using BioSequences
using DataFrames
using FASTX

struct Mutation
    from::String
    position::Int64
    to::String
    string_location::Int64
    details::Dict{Char, DataFrame}
end

struct Summary
    cluster::String
    proteins::Int64
    mutations::Dict{String, Mutation}
end

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster folders with summary files required"
            required = true
        "--output", "-o"
            help = "Output directory. Metrics files for each cluster will be saved here. Ignore to use input directory"
        "--extension", "-e"
            help = "Summary file extension. Default is .summary"
            default = ".summary"
        "--sov_refine", "-s"
            help = "Path to SOV_refine perl script to produce metrics. Usually called SOV_refine.pl"
            required = true
        "--clean", "-c"
            help = "Delete SOV_refine input files after benchmark is done"
            action = :store_true
        "--mutations_file", "-m"
            help = "Output a mutations secondary structure file for analysis"
            action = :store_true
    end
    return parse_args(s)
end

function read_summary(f_path)
    summary = nothing
    reader = open(f_path, "r")
    cluster, proteins, mutations = split(readline(reader), " - ")
    protein_num = parse(Int64, first(split(proteins, ' ')))
    #mutation_num = parse(Int64, first(split(mutations, ' ')))
    col_line = readline(reader)
    if !startswith(col_line, '#')
        throw(ErrorException("Wrong file format or corrupted file"))
    end
    summary = Summary(cluster, protein_num, Dict())
    cols = split(chop(col_line, head = 1, tail=0), '\t')
    current_mutation = nothing
    current_mutation_id = ""
    current_mutation_detail = '.'
    current_details = []
    mut_regex = r"^([-+])(\w)(\d+)(\w)"
    while !eof(reader)
        line = readline(reader)
        if startswith(line, '-') || startswith(line, '+')
            if !isempty(current_details)
                df =  DataFrame([getindex.(current_details, i) for i in 1:length(cols)], :auto, copycols=false)
                rename!(df, cols)
                try
                    summary.mutations[current_mutation_id].details[current_mutation_detail] = df
                catch e
                    current_mutation.details[current_mutation_detail] = df
                    summary.mutations[current_mutation_id] = current_mutation
                end
            end
            mut_regex_matches = match(mut_regex, line).captures
            current_mutation_id = join(mut_regex_matches[2:4])
            current_mutation_detail = only(mut_regex_matches[1])
            from = mut_regex_matches[2]
            position = parse(Int64, mut_regex_matches[3])
            to = mut_regex_matches[4]
            string_loc = findfirst('*', last(split(line, '\t')))
            string_loc = isnothing(string_loc) ? 1 : string_loc
            current_mutation = Mutation(from, position, to, string_loc, Dict())
            current_details = []
        else
            push!(current_details, split(line, '\t'))
        end
    end
    if !isempty(current_details)
        df =  DataFrame([getindex.(current_details, i) for i in 1:length(cols)], :auto, copycols=false)
        rename!(df, cols)
        try
            summary.mutations[current_mutation_id].details[current_mutation_detail] = df
        catch e
            current_mutation.details[current_mutation_detail] = df
            summary.mutations[current_mutation_id] = current_mutation
        end
    end
    close(reader)
    return summary
end

function pm1(a, side)
    return side == "back" ? a - 1 : a + 1
end

function get_neighbor_ss(seq, pos, side)
    current_AA = seq[pos]
    current_pos = pos
    while current_AA == seq[pos]
        try
            current_pos = pm1(current_pos, side)
            current_AA = seq[current_pos]
        catch e
            break
        end
    end
    return current_AA
end

function create_benchmark_files(summary, out_dir, cluster_num)
    tool_names = []
    cluster_ids = []
    mut_proteins = Dict{String, Set{String}}()
    for (mut_name, mut) in summary.mutations
        aa_details = mut.details['-']
        if isempty(tool_names)
            tool_names = names(aa_details)
            deleteat!(tool_names, 1:3)
        end
        if isempty(cluster_ids)
            cluster_ids = aa_details[!, :id]
        end
        mut_proteins[mut_name] = Set(filter(row -> row.sequence == mut.to, aa_details)[!, :id])
    end
    mkpath(out_dir)
    for (mut_name, mut) in summary.mutations
        local_details = mut.details['+']
        dssp_out = joinpath(out_dir, "$(mut_name).ref.fa")
        if !isfile(dssp_out)
            for row in eachrow(local_details)
                mutation_description = row["id"] in mut_proteins[mut_name] ? "mutation" : "consensus"
                FASTA.Writer(open(dssp_out, "a")) do writer
                    write(writer, FASTA.Record("$(row["id"])_$(mut_name)_dssp", mutation_description, LongCharSeq(row["dssp"])))
                end
            end
        end
        for tool in tool_names
            tool_out = joinpath(out_dir, "$(tool)-$(mut_name).pred.fa")
            if !isfile(tool_out)
                for row in eachrow(local_details)
                    mutation_description = row["id"] in mut_proteins[mut_name] ? "mutation" : "consensus"
                    FASTA.Writer(open(tool_out, "a")) do writer
                        write(writer, FASTA.Record("$(row["id"])_$(mut_name)_$(tool)", mutation_description, LongCharSeq(row[tool])))
                    end
                end
            end
        end
    end
    if parsed_args["mutations_file"]
        #create tsv file with header
        mut_ss_out = joinpath(out_dir, "Cluster.mutss")
        if !isfile(mut_ss_out)
            open(mut_ss_out, "w") do writer
                println(writer, "cluster\ttool\tmutation\tAAMutation\tpos\tdesc\tss\tleft_ss\tright_ss\tpred_ss\tleft_pred_ss\tright_pred_ss")
            end
            mut_ss_io = open(mut_ss_out, "a")
            for (mut_name, mut) in summary.mutations
                aamut = "$(mut.from)_$(mut.to)"
                local_details = mut.details['+']
                for tool in tool_names
                    for row in eachrow(local_details)
                        mut_desc = row["id"] in mut_proteins[mut_name] ? "mutation" : "consensus"
                        sstruc = row["dssp"][mut.string_location]
                        l_sstruc = get_neighbor_ss(row["dssp"], mut.string_location, "back")
                        r_sstruc = get_neighbor_ss(row["dssp"], mut.string_location, "")
                        pred_ss = row[tool][mut.string_location]
                        l_pred_ss = get_neighbor_ss(row[tool], mut.string_location, "back")
                        r_pred_ss = get_neighbor_ss(row[tool], mut.string_location, "")
                        println(mut_ss_io, "$(cluster_num)\t$(tool)\t$(mut_name)\t$(aamut)\t$(mut.position)\t$(mut_desc)\t$(sstruc)\t$(l_sstruc)\t$(r_sstruc)\t$(pred_ss)\t$(l_pred_ss)\t$(r_pred_ss)")
                    end
                end
            end
            close(mut_ss_io)
        end
    end
end

function calculate_metrics(bmk_dir)
    #Find .pred.fa files inside benchmark folder (assume .ref.fa with same name after -)
    ref_path = nothing
    for pred_path in glob("*.pred.fa", bmk_dir)
        f_basename = first(split(basename(pred_path), '.'))
        ref_path = joinpath(bmk_dir, "$(last(split(f_basename, '-'))).ref.fa")
        #Run sov_refine to obtain metrics
        out_file = joinpath(bmk_dir, "$(f_basename).metrics")
        if !isfile(out_file)
            write(out_file, read(`$(parsed_args["sov_refine"]) $(ref_path) $(pred_path)`))
        end
        if parsed_args["clean"]
            rm(pred_path)
        end
    end
    if parsed_args["clean"]
        rm(ref_path)
    end
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for dir in dirs
        if startswith(dir, "Cluster")
            cluster_dir = joinpath(root, dir)
            f_path_no_root_folder = lstrip(replace(cluster_dir, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = joinpath(parsed_args["output"], f_path_no_root_folder)
            bmk_out_dir = joinpath(f_out_dir, "local_benchmark")
            for f in glob("*$(parsed_args["extension"])", cluster_dir)
                f_name = basename(f)
                summary = read_summary(f)
                #Make files for input to sov_refine inside benchmark folder
                create_benchmark_files(summary, bmk_out_dir, last(split(dir, '_')))
                #Per tool and mutation local benchmark inside benchmark folder
                calculate_metrics(bmk_out_dir)
            end
        end
    end
end