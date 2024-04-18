#!/bin/bash
grep "scientific name" names.dmp | sed 's/^\([0-9]*\)\t|\t\(.*\)\t|\t.*\t|.*name\t|$/taxon:\1\t\2/' > scientific_names.txt