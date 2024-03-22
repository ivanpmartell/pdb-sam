#!/bin/bash
find $1 -name "*.mut" | xargs wc -l | sed -e 's/^ \+\([0-9]\+\) .*\/\(Cluster_[0-9]\+\)\/.*$/\2 \1/g' | head -n -1 > mutations_cluster.txt