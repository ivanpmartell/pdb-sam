#!/bin/bash
current_dir="$(pwd)"
git clone --recursive https://github.com/soedinglab/CCMpred.git
cd CCMpred
cmake .
make
export PATH="$current_dir/CCMpred/bin:$PATH"
cd $current_dir

git clone --branch v3.3.0 https://github.com/soedinglab/hh-suite.git
mkdir -p hh-suite/build && cd hh-suite/build
cmake -DCMAKE_INSTALL_PREFIX=. ..
make -j 4 && make install
export PATH="$current_dir/hh-suite/bin:$PATH"
cd $current_dir

wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.8.1/ncbi-blast-2.8.1+-x64-linux.tar.gz && \
    tar xvf ncbi-blast-2.8.1+-x64-linux.tar.gz && \
    rm -f ncbi-blast-2.8.1+-x64-linux.tar.gz
export PATH="$current_dir/ncbi-blast-2.8.1+/bin"
cd $current_dir

wget -q -P /tmp https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p "$current_dir/conda"
rm /tmp/Miniconda3-latest-Linux-x86_64.sh
export PATH="$current_dir/conda/bin:$PATH"
export LD_LIBRARY_PATH="$current_dir/conda/lib:$LD_LIBRARY_PATH"
conda init
conda create -y -n spot1d python=2.7
conda activate spot1d
pip install pandas tqdm scipy numpy==1.16.1 tensorflow==1.4.0
cd $current_dir

sudo apt update
sudo apt install liblapack3 libblas3 liblapack-dev libopenblas-dev
wget https://apisz.sparks-lab.org:8443/downloads/Resource/Protein/2_Protein_local_structure_prediction/SPOT-Contact_local.tgz
tar xf SPOT-Contact_local.tgz
cd SPOT-Contact-Helical-New/sources/DCA/
make clean
make
cd $current_dir

wget https://apisz.sparks-lab.org:8443/downloads/Resource/Protein/2_Protein_local_structure_prediction/old_versions/SPIDER3_local.tgz
tar xf SPIDER3_local.tgz

wget https://apisz.sparks-lab.org:8443/downloads/SPOT-1D-local.tar.gz
tar xzf SPOT-1D-local.tar.gz
cd SPOT-1D-local
chmod +x run_spot1d.sh
chmod +x run_all_models.py
cd $current_dir

echo "IMPORTANT: MODIFY run_spot1d.sh script with local paths"

#Databases
sudo apt install perl
mkdir databases
cd databases
wget https://wwwuser.gwdg.de/~compbiol/data/hhsuite/databases/hhsuite_dbs/old-releases/uniprot20_2013_03.tar.gz
tar xzf uniprot20_2013_03.tar.gz
mkdir nr
cd nr
update_blastdb.pl --decompress nr