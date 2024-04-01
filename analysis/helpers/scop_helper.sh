#!/bin/bash
#Usage scop_helper.sh scop-cla-latest.txt scop-represented-structures-latest.txt
grep -o '^[^!#][^!:]*:' $1 | sed 's/:$//' >> $2