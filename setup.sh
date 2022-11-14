apt-get -y update && apt-get install -y wget build-essential zlib1g zlib1g-dev python3-pip ttf-mscorefonts-installer

wget https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.2-linux-x86_64.tar.gz && \
    tar xvf julia-1.8.2-linux-x86_64.tar.gz

wget https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz && \
    tar xvf cd-hit-v4.8.1-2019-0228.tar.gz && \
    rm -f cd-hit-v4.8.1-2019-0228.tar.gz \
    mv cd-hit-v4.8.1-2019-0228 cd-hit && \
    cd cd-hit && \
    make && \
    cd cd-hit-auxtools && \
    make && \
    cd ../..

wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.8.1/ncbi-blast-2.8.1+-x64-linux.tar.gz && \
    tar xvf ncbi-blast-2.8.1+-x64-linux.tar.gz && \
    rm -f ncbi-blast-2.8.1+-x64-linux.tar.gz

wget http://www.clustal.org/omega/clustalo-1.2.4-Ubuntu-x86_64 && \
    chmod +x clustalo-1.2.4-Ubuntu-x86_64 && \
    mv clustalo-1.2.4-Ubuntu-x86_64 ncbi-blast-2.8.1+/bin/clustalo

wget wget ftp://emboss.open-bio.org/pub/EMBOSS/emboss-latest.tar.gz && \
    tar xvf emboss-latest.tar.gz && \
    rm -f emboss-latest.tar.gz && \
    cd EMBOSS-6.6.0 && \
    ./configure --prefix=/usr/local/emboss --without-x && \
    make && \
    make install && \
    cd ..

echo "Add the following folders to PATH: cd-hit/  cd-hit/cd-hit-auxtools  cd-hit/psi-cd-hit  ncbi-blast-2.8.1+/bin julia-1.8.2/bin"
echo "Replace pdb-sam with full path to repository folder: PATH=pdb-sam/julia-1.8.2/bin:pdb-sam/cd-hit:pdb-sam/cd-hit/cd-hit-auxtools:pdb-sam/cd-hit/psi-cd-hit:pdb-sam/ncbi-blast-2.8.1+/bin:/usr/local/emboss/bin:${PATH}"
echo "Add julia and python libraries in README.md"