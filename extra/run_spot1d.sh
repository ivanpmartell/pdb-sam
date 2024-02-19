#!/bin/bash

################################################################################
#UPDATE these to the correct installation directories or values
psiblastdir=''
spotcontactdir=/home/ivan/spot1d/SPOT-Contact-Helical-New
hhblitsdir=''
hhsuitedir=/home/ivan/spot1d/hh-suite
nrdir=/home/ivan/databases/nr_clustered/nr_cluster_seq
uniprotdir=/home/ivan/databases/uniprot20_2013_03/uniprot20_2013_03
ncpu=16
spider3dir=/home/ivan/spot1d/SPD3-numpy
spot1ddir=/home/ivan/spot1d/SPOT-1D-local
################################################################################

export HHLIB=$hhsuitedir
#Generate the input file list

#-------------------------------------------------------------------------------
# RUN ON ALL FASTA FILES IN INPUT
find $spot1ddir/inputs -name "*.fasta" | sed "s:.fasta::" | sed "s:.*/::" > protlist.txt #COMMENT THIS LINE OUT IF YOU HAVE YOUR OWN PROTLIST.TXT!!
#-------------------------------------------------------------------------------
# RUN ONLY ON SPECIFIED FILES IN PROTLIST.txt
prots=`sed -e "s:^:$spot1ddir/inputs/:" protlist.txt`
#-------------------------------------------------------------------------------
orig_dir=`pwd`
for i in $prots; do
	protname=`echo $i | sed "s:.*/\(.*\):\1:"`   
    echo "Protein: $protname"
    echo $(date)
    echo "Generating HHblits outputs..."
        [ -f $i.hhm -o -f $i.a3m ] || ${hhblitsdir}hhblits -i $i.fasta -ohhm $i.hhm -oa3m $i.a3m -d $uniprotdir -v 0 -maxres 40000 -cpu $ncpu -Z 0
    echo "Generating PSSM..."
    if [ ! -f $i.pssm ]; then
        if ${psiblastdir}psiblast -db $nrdir -num_iterations 3 -num_alignments 1 -num_threads $ncpu -query $i.fasta -out  $i.bla -out_ascii_pssm $i.pssm ; then
            echo "Successfully obtained PSSM"
        else
            echo "Error on PSSM. Skipping file"
            rm $i.pssm
            continue
        fi
    fi
    if [ ! -f $i.pssm ] || [ ! -f $i.hhm ] || [ ! -f $i.a3m ]; then
        echo "Missing Psiblast or HHblits output. Skipping..."
        continue
    fi
    echo "Generating SPIDER3 outputs..."
    cd inputs
    [ -f $i.spd33 ] || ${spider3dir}/script/spider3_pred.py $protname --odir "$spot1ddir/inputs/"
    cd $orig_dir
    cd $spotcontactdir
    echo "Generating CCMPRED outputs..."
    [ -f $i.mat ] || sources/CCMpred/calCCMpred.sh $i.a3m
    [ -f $protname.mat ] && mv $protname.mat $spot1ddir/inputs/
    echo "Generating DCA outputs..."
    [ -f $i.di ] || sources/DCA/calDI.sh $i.a3m
    [ -f $protname.di ] && mv $protname.di $spot1ddir/inputs/
    cd $orig_dir
done
#GPU Prediction below
echo "SPOT-Contact features collected! Running SPOT-Contact..."
cd $spotcontactdir
rm -rf $spot1ddir/spotconlist
touch $spot1ddir/spotconlist
for i in $prots; do 
	protname=`echo $i | sed "s:.*/\(.*\):\1:"`   
    [[ -f $i.spotcon ]] || echo $protname >> $spot1ddir/spotconlist
done
if [[ -s $spot1ddir/spotconlist ]]; then
    $spotcontactdir/scripts/run_all_models.py --input_list "$spot1ddir/spotconlist" --gpu 0 --input_dir $spot1ddir/
    for i in $prots; do 
	    protname=`echo $i | sed "s:.*/\(.*\):\1:"` 
        mv $spotcontactdir/outputs/$protname.spotcon $spot1ddir/inputs/
    done
fi
rm -rf $spot1ddir/spotconlist
cd $orig_dir
echo "All features collected! Running SPOT-1D..."
$spot1ddir/run_all_models.py --input_list "protlist.txt" --gpu 0
#remove intermediate files- comment out if unnecessary
find $spot1ddir/outputs -name '*[0-9]' | xargs rm
