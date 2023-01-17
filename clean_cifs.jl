using ArgParse
using ProgressBars
using FASTX
using BioSequences
using Glob

struct AACoverage
    position::Int64
    aa::AminoAcid
    coverage_seqs::Set{Int64}
end

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster containing cif files and aligned sequences should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cleaned cif clusters with unique variants will be saved here. Ignore to write files in input directory"
    end
    return parse_args(s)
end

function get_seq_coverage(records, seqs_length)
    aa_coverage = Vector{Dict{AminoAcid,Set{Int64}}}(undef, seqs_length)
    seq_gaps = Vector{Int64}()
    for i in eachindex(records)
        seq = sequence(LongAminoAcidSeq, records[i])
        gap_count = 0
        for l in eachindex(seq)
            if seq[l] == AA_Gap #only check non-gaps
                gap_count += 1
                continue
            end
            try
                push!(aa_coverage[l][seq[l]], i)
            catch e
                if isa(e, UndefRefError)
                    aa_coverage[l] = Dict(seq[l] => Set([i]))
                elseif isa(e, KeyError)
                    aa_coverage[l][seq[l]] = Set([i])
                else
                    print("Unexpected error occured: $e")
                    exit(1)
                end
            end
        end
        push!(seq_gaps, gap_count)
    end
    return aa_coverage
end

function get_indispensable_seqs(aa_coverage, seqs_length)
    sorted_coverage = Vector{AACoverage}()
    for i in 1:seqs_length
        try
            coverage_keys = collect(keys(aa_coverage[i]))
            if length(coverage_keys) < 2
                continue
            end
            for k in coverage_keys
                push!(sorted_coverage, AACoverage(i, k, aa_coverage[i][k]))
            end
        catch
            continue
        end
    end
    sorted_coverage = sort!(sorted_coverage, by=e->length(e.coverage_seqs))

    indispensable_seqs = Set{Int64}()
    for i in eachindex(sorted_coverage)
        c_pos = sorted_coverage[i].position
        if c_pos == -1
            continue
        end
        current_seq = first(sorted_coverage[i].coverage_seqs)
        push!(indispensable_seqs, current_seq)
        #Remove from sorted coverage if covered by indispensable seq
        for j in eachindex(sorted_coverage)
            if in(current_seq, sorted_coverage[j].coverage_seqs)
                sorted_coverage[j] = AACoverage(-1,AA_X,Set(0))
            end
        end
    end
    return indispensable_seqs
end

function keep_indispensable_seqs(records, indispensable_seqs, file_out, file_in)
    total_recs = length(records)
    keepat!(records, sort!(collect(indispensable_seqs)))
    indispensable_recs = Set{String}()
    if length(indispensable_seqs) == total_recs
        if !(file_in == file_out)
            cp(dirname(file_in), dirname(file_out), force=true)
            return
        else
            return
        end
    elseif length(indispensable_seqs) == 0
        if !(file_in == file_out)
            #if output folder is different then skip
            return
        else
            #if output folder == input folder then delete folder
            rm(dirname(file_out), recursive=true)
            return
        end
    else
        for rec in records
            push!(indispensable_recs, identifier(rec))
        end
        if !(file_in == file_out)
            #if output folder is different then copy indispensable cif into output folder
            for cif_path in glob("*.cif", dirname(file_in))
                cif_file = last(split(cif_path, "/"))
                if in(replace(cif_file, r".cif$"=>""), indispensable_recs)
                    output_filepath = joinpath(dirname(file_out), cif_file)
                    ensure_new_file(output_filepath)
                    cp(cif_path, output_filepath, force=true)
                end
            end
        else
            #if output folder == input folder then delete unnecessary cif
            for cif_path in glob("*.cif", dirname(file_in))
                cif_file = last(split(cif_path, "/"))
                if in(replace(cif_file, r".cif$"=>""), indispensable_recs)
                    rm(cif_path)
                end
            end
        end
    end
    # rewrite .ala and .fa
    #records is rewritten .ala
    ensure_new_file(file_out)
    for rec in records
        FASTA.Writer(open(file_out, "a")) do writer
            write(writer, rec)
        end
    end
    #read .fa and remove unnecessary ids
    non_aligned_input = replace(file_in, r".ala$"=>"")
    if isfile(non_aligned_input)
        non_aligned_output = replace(file_out, r".ala$"=>"")
        non_aligned_records = Vector{FASTX.FASTA.Record}()
        FASTA.Reader(open(non_aligned_input)) do reader
            non_aligned_records = collect(reader)
        end
        ensure_new_file(non_aligned_output)
        for rec in non_aligned_records
            if in(identifier(rec), indispensable_recs)
                FASTA.Writer(open(non_aligned_output, "a")) do writer
                    write(writer, rec)
                end
            end
        end
    end
end

function ensure_new_file(f)
    if !(isfile(f))
        mkpath(dirname(f))
        touch(f)
    else
        rm(f)
        ensure_new_file(f)
    end
end

parsed_args = parse_commandline()
mkpath(dirname(parsed_args["output"]))
for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if f == "cif_sequences.fa.ala"
            f_path = joinpath(root,f)
            records = Vector{FASTX.FASTA.Record}()
            FASTA.Reader(open(f_path)) do reader
                records = collect(reader)
            end
            seqs_length = length(sequence(LongAminoAcidSeq, records[1]))
            aa_coverage = get_seq_coverage(records, seqs_length)
            # Find records that do not contribute to the mutations (gap or all mutations in seq are contained in another one)
            #Remove if covered previously TODO: also sort by gap count
            indispensable_seqs = get_indispensable_seqs(aa_coverage, seqs_length)
            #TODO: remove unnecessary records (remake files if they change and delete according cif files)
            f_path = joinpath(root,f)
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_path = joinpath(parsed_args["output"], f_path_no_root_folder)
            keep_indispensable_seqs(records, indispensable_seqs, f_out_path, f_path)
        end
    end
end