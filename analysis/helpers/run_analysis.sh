#!/bin/bash
julia analysis/consensus.jl -i $1 > consensus_matching.txt
julia analysis/mutations.jl -i $1
julia analysis/sequences_length.jl -i $1 > lengths.txt
find $1 -name "*.mut" | xargs wc -l | sed -e 's/^ \+\([0-9]\+\) .*\/\(Cluster_[0-9]\+\)\/.*$/\2 \1/g' > mutations_cluster.txt
