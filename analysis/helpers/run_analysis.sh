#!/bin/bash
julia analysis/consensus.jl -i ~/research/clusters/ > consensus_matching.txt
julia analysis/mutations.jl -i ~/research/clusters/
julia analysis/sequences_length.jl -i ~/research/clusters/ > lengths.txt
find ~/research/clusters/ -name "*.mut" | xargs wc -l | sed -e 's/^ \+\([0-9]\+\) .*\/\(Cluster_[0-9]\+\)\/.*$/\2 \1/g' > mutations_cluster.txt
