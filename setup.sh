apt-get -y update && apt-get install -y wget build-essential zlib1g zlib1g-dev python3-pip ttf-mscorefonts-installer bison flex

wget https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.0-linux-x86_64.tar.gz && \
    tar xvf julia-1.10.0-linux-x86_64.tar.gz && \
    rm -f julia-1.10.0-linux-x86_64.tar.gz

wget https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz && \
    tar xvf cd-hit-v4.8.1-2019-0228.tar.gz && \
    rm -f cd-hit-v4.8.1-2019-0228.tar.gz && \
    mv cd-hit-v4.8.1-2019-0228 cd-hit && \
    cd cd-hit && \
    make && \
    cd cd-hit-auxtools && \
    make && \
    cd ../..

wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.15.0/ncbi-blast-2.15.0+-x64-linux.tar.gz && \
    tar xvf ncbi-blast-2.15.0+-x64-linux.tar.gz && \
    rm -f ncbi-blast-2.15.0+-x64-linux.tar.gz

wget http://www.clustal.org/omega/clustalo-1.2.4-Ubuntu-x86_64 && \
    chmod +x clustalo-1.2.4-Ubuntu-x86_64 && \
    mv clustalo-1.2.4-Ubuntu-x86_64 ncbi-blast-2.15.0+/bin/clustalo

wget ftp://emboss.open-bio.org/pub/EMBOSS/emboss-latest.tar.gz && \
    tar xvf emboss-latest.tar.gz && \
    rm -f emboss-latest.tar.gz && \
    cd EMBOSS-6.6.0 && \
    ./configure --prefix=/usr/local/emboss --without-x && \
    make && \
    make install && \
    cd ..

wget http://dna.cs.miami.edu/SOV/SOV_refine.tar.gz && \
    tar xzf SOV_refine.tar.gz && \
    rm -f SOV_refine.tar.gz

wget https://sw-tools.rcsb.org/apps/MAXIT/maxit-v11.100-prod-src.tar.gz && \
    tar xzf maxit-v11.100-prod-src.tar.gz && \
    cd maxit-v11.100-prod-src && \
    make binary && \
    cd ..

wget https://github.com/PDB-REDO/dssp/releases/download/v4.4.0/mkdssp-4.4.0-linux-x64 && \
    chmod +x mkdssp-4.4.0-linux-x64 && \
    mv mkdssp-4.4.0-linux-x64 maxit-v11.100-prod-src/bin/mkdssp

echo "Add the following folders to PATH inside the ~/.profile and ~/.bashrc file: cd-hit/  cd-hit/cd-hit-auxtools  cd-hit/psi-cd-hit  ncbi-blast-2.15.0+/bin julia-1.8.2/bin"
echo "Replace pdb-sam with full path to repository folder: PATH=\"pdb-sam/julia-1.8.2/bin:pdb-sam/cd-hit:pdb-sam/cd-hit/cd-hit-auxtools:pdb-sam/cd-hit/psi-cd-hit:pdb-sam/ncbi-blast-2.15.0+/bin:/usr/local/emboss/bin:\$PATH\""
echo "Add julia and python libraries from README.md"

echo "export PATH=\"$(pwd)/maxit-v11.100-prod-src/bin:$(pwd)/julia-1.10.0/bin:$(pwd)/cd-hit:$(pwd)/cd-hit/cd-hit-auxtools:$(pwd)/cd-hit/psi-cd-hit:$(pwd)/ncbi-blast-2.15.0+/bin:/usr/local/emboss/bin:\$PATH\"" >> ~/.profile
echo "export PATH=\"$(pwd)/maxit-v11.100-prod-src/bin:$(pwd)/julia-1.10.0/bin:$(pwd)/cd-hit:$(pwd)/cd-hit/cd-hit-auxtools:$(pwd)/cd-hit/psi-cd-hit:$(pwd)/ncbi-blast-2.15.0+/bin:/usr/local/emboss/bin:\$PATH\"" >> ~/.bashrc
echo "export RCSBROOT=$(pwd)/maxit-v11.100-prod-src" >> ~/.bashrc

"$(pwd)/julia-1.10.0/bin/julia" -e 'using Pkg; Pkg.add(["ArgParse", "ProgressBars", "FASTX", "BioStructures", "BioSequences", "LogExpFunctions", "Pandas", "DataFrames"])'
