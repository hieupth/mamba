# -----------------------------------------------------------------------------
# SETUP NVIDIA CUDA IMAGE
# -----------------------------------------------------------------------------
# Desired CUDA version of the image.
ARG NV_CUDA=11.6.2
# Desired CuDNN version of the image.
ARG NV_CUDNN=8
# Desired target OS of the image.
ARG NV_OS=ubuntu20.04
# Desired target flavor of the image. Can be "runtime" or "devel".
ARG NV_FLAVOR=runtime
# The image will be built from suitable Nvidia's CUDA images.
FROM nvidia/cuda:${NV_CUDA}-cudnn${NV_CUDNN}-${NV_FLAVOR}-${NV_OS}
ARG NV_CUDA
# -----------------------------------------------------------------------------
# GENERAL SETTINGS
# -----------------------------------------------------------------------------
# Deactive interactive UI.
ENV DEBIAN_FRONTEND=noninteractive
# Install common packages
SHELL ["/bin/bash", "-c"]
RUN apt-get update > /dev/null && \
    NV_CUDA=${NV_CUDA//./-}; apt-get install cuda-cupti-${NV_CUDA:0:-2} -y && \
    apt-get install --no-install-recommends --yes \
        git wget curl bzip2 cmake ca-certificates build-essential > /dev/null && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# INSTALL TINI
# -----------------------------------------------------------------------------
# Desired tini version.
ARG TINI_VERSION=v0.19.0
# Install tini.
RUN wget --no-hsts --quiet https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-$(dpkg --print-architecture) -O /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

## -----------------------------------------------------------------------------
# INSTALL MINICONDA (MINIFORGE)
# ------------------------------------------------------------------------------
# Desired miniforge.
ARG MINIFORGE_NAME=Miniforge3
# Desired miniforge version.
ARG MINIFORGE_VERSION=4.12.0-2
# Desired miniforge environment variables.
ENV CONDA_DIR=/opt/conda
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=${CONDA_DIR}/bin:${PATH}
# Install miniforge.
RUN wget --no-hsts --quiet https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/${MINIFORGE_NAME}-${MINIFORGE_VERSION}-Linux-$(uname -m).sh -O /tmp/miniforge.sh && \
    /bin/bash /tmp/miniforge.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniforge.sh && \
    conda clean -tipsy && \
    find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
    find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete && \
    conda clean -afy && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc

# -----------------------------------------------------------------------------
# SETUP ENTRYPOINT
# -----------------------------------------------------------------------------
ENTRYPOINT ["tini", "--"]
CMD [ "/bin/bash" ]
