#!/bin/bash
NVARCH=x86_64
NV_CUDA_CUDART_VERSION=11.1.74-1
NV_CUDA_COMPAT_PACKAGE=cuda-compat-11-1
CUDA_VERSION=11.1.1
LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,utility
NV_CUDA_LIB_VERSION=11.1.1-1
NV_NVTX_VERSION=11.1.74-1
NV_LIBNPP_VERSION=11.1.2.301-1
NV_LIBNPP_PACKAGE=libnpp-11-1=11.1.2.301-1
NV_LIBCUSPARSE_VERSION=11.3.0.10-1
NV_LIBCUBLAS_PACKAGE_NAME=libcublas-11-1
NV_LIBCUBLAS_VERSION=11.3.0.106-1
NV_LIBCUBLAS_PACKAGE=libcublas-11-1=11.3.0.106-1
NV_LIBNCCL_PACKAGE_NAME=libnccl2
NV_LIBNCCL_PACKAGE_VERSION=2.8.4-1
NCCL_VERSION=2.8.4-1
NV_LIBNCCL_PACKAGE=libnccl2=2.8.4-1+cuda11.1
NVIDIA_PRODUCT_NAME=CUDA
NV_CUDNN_VERSION=8.0.5.39
NV_CUDNN_PACKAGE_NAME=libcudnn8
NV_CUDNN_PACKAGE=libcudnn8=8.0.5.39-1+cuda11.1

git clone https://github.com/google-deepmind/alphafold.git

apt-get update
apt-get install -y --no-install-recommends gnupg2 curl ca-certificates
curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/$NVARCH/3bf863cc.pub | apt-key add -
echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/$NVARCH /" > /etc/apt/sources.list.d/cuda.list
apt-get purge --autoremove -y curl
rm -rf /var/lib/apt/lists/* # buildkit

apt-get update
apt-get install -y --no-install-recommends cuda-cudart-11-1=$NV_CUDA_CUDART_VERSION $NV_CUDA_COMPAT_PACKAGE
ln -s cuda-11.1 /usr/local/cuda
rm -rf /var/lib/apt/lists/* # buildkit
echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf
echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf # buildkit

#add to .bashrc
export PATH=$PATH:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

apt-get update
apt-get install -y --no-install-recommends cuda-libraries-11-1=$NV_CUDA_LIB_VERSION $NV_LIBNPP_PACKAGE cuda-nvtx-11-1=$NV_NVTX_VERSION libcusparse-11-1=$NV_LIBCUSPARSE_VERSION $NV_LIBCUBLAS_PACKAGE $NV_LIBNCCL_PACKAGE
rm -rf /var/lib/apt/lists/* # buildkit
apt-mark hold $NV_LIBCUBLAS_PACKAGE_NAME $NV_LIBNCCL_PACKAGE_NAME # buildkit

apt-get update
apt-get install -y --no-install-recommends     $NV_CUDNN_PACKAGE
apt-mark hold $NV_CUDNN_PACKAGE_NAME
rm -rf /var/lib/apt/lists/* # buildkit

##AF2 dockerfile

apt-get update
apt-get install --no-install-recommends -y \
        build-essential \
        cmake \
        cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA_VERSION//./-}) \
        git \
        hmmer \
        kalign \
        tzdata \
        wget
rm -rf /var/lib/apt/lists/*
apt-get autoremove -y
apt-get clean

git clone --branch v3.3.0 https://github.com/soedinglab/hh-suite.git /tmp/hh-suite
mkdir /tmp/hh-suite/build
pushd /tmp/hh-suite/build
cmake -DCMAKE_INSTALL_PREFIX=/opt/hhsuite ..
make -j 4 && make install
ln -s /opt/hhsuite/bin/* /usr/bin
popd
rm -rf /tmp/hh-suite

wget -q -P /tmp https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda
rm /tmp/Miniconda3-latest-Linux-x86_64.sh

#add this to .bashrc too
export PATH="/opt/conda/bin:$PATH"
export LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"

conda install -qy conda==23.5.2
conda install -y -c conda-forge \
      openmm=7.7.0 \
      cudatoolkit==$CUDA_VERSION \
      pdbfixer \
      pip \
      python=3.10
conda clean --all --force-pkgs-dirs --yes

cd alphafold
mkdir --parents /app/alphafold
cp -r . /app/alphafold

wget -q -P /app/alphafold/alphafold/common/ \
  https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

pip3 install --upgrade pip --no-cache-dir
pip3 install -r /app/alphafold/requirements.txt --no-cache-dir
pip3 install --upgrade --no-cache-dir \
      jax==0.3.25 \
      jaxlib==0.3.25+cuda11.cudnn805 \
      -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

chmod u+s /sbin/ldconfig.real

echo $'#!/bin/bash\n\
ldconfig\n\
python /app/alphafold/run_alphafold.py "$@"' > /app/run_alphafold.sh
chmod +x /app/run_alphafold.sh