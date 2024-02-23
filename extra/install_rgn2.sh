#!/bin/bash
sudo apt install git-lfs
git clone https://github.com/aqlaboratory/rgn2
cd rgn2
conda env create -f environment.yml
git clone --branch v2.2.4 https://github.com/deepmind/alphafold.git alphafold
conda create -y -q --name af2 python=3.7
conda activate af2
pip install --upgrade jax==0.3.17       jaxlib==0.3.15+cuda11.cudnn82       -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
pip install -r ./alphafold/requirements.txt
pip install --no-dependencies ./alphafold
mkdir --parents ./alphafold/data/params
wget -O ./alphafold/data/params/alphafold_params_2022-03-02.tar https://storage.googleapis.com/alphafold/alphafold_params_2022-03-02.tar
tar --extract --verbose --file="./alphafold/data/params/alphafold_params_2022-03-02.tar" --directory="./alphafold/data/params" --preserve-permissions
rm alphafold/data/params/alphafold_params_2022-03-02.tar
GIT_LFS_SKIP_SMUDGE=1 git clone "https://huggingface.co/christinafl/rgn2" resources
cd resources/
git lfs pull
mv rgn2_runs ../runs
cd ..
wget -O ter2pdb/ModRefiner-l.zip https://zhanggroup.org/ModRefiner/ModRefiner-l.zip
cd ter2pdb
unzip ModRefiner-l.zip
rm ModRefiner-l.zip