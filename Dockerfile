# Set OS version.
ARG TARGET_ARCH=amd64
ARG TARGET_OS=ubuntu20.04
ARG TARGET_RUNTIME=runtime
# Set cuda version.
ARG CUDA_VERSION=11.6.2
ARG CUDNN_VERSION=8
# Set miniconda version.
ARG MINIFORGE_NAME=Miniforge3
ARG MINIFORGE_VERSION=4.10.2-0
# Set tini version.
ARG TINI_VERSION=v0.19.0
# Build from NVIDIA's images.
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-${TARGET_RUNTIME}-${TARGET_OS}
# Set conda environments.
ENV CONDA_DIR=/opt/conda
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=${CONDA_DIR}/bin:${PATH}
# Install necessary packages.
RUN rm /etc/apt/sources.list.d/* && \
    apt-get update && \
    apt-get install --no-install-recommends \
        wget curl git bzip2 ca-certificates cmake build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# Install tini.
RUN wget --no-hsts --quiet https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGET_ARCH} -O /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini
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
# Finalise image.
ENTRYPOINT ["tini", "--"]