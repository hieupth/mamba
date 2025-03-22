ARG BASE=ubuntu:24.04
ARG MINIFORGE=Miniforge3
ARG PACKAGES

FROM ${BASE}
# Recall build args.
ARG PACKAGES
ARG MINIFORGE
# Useful envinronment.
ENV DEBIAN_FRONTEND=noninteractive
# Install required packages.
RUN apt-get update --yes && \
    # Install basic packages.
    apt-get install --yes --no-install-recommends \
        curl \
        gnupg \
        ca-certificates \
        tini \
        git \
        # .NET dependencies.
        libc6 \
        libgcc-s1 \
        libicu74 \
        libssl3t64 \
        libstdc++6 \
        tzdata \
        tzdata-legacy \
        # Additional packages.
        ${PACKAGES} && \
    # Clean cache.
    apt-get clean && rm -rf /var/lib/apt/lists/*
# Set conda environments.
ENV CONDA_DIR=/opt/conda
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=${CONDA_DIR}/bin:${PATH}
# Install miniforge.
RUN curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/${MINIFORGE}-$(uname)-$(uname -m).sh && \
    chmod +x /${MINIFORGE}-$(uname)-$(uname -m).sh && \
    /${MINIFORGE}-$(uname)-$(uname -m).sh -b -p ${CONDA_DIR} && \
    rm /${MINIFORGE}-$(uname)-$(uname -m).sh && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
    mamba clean -ay
# Set tini.
ENTRYPOINT ["tini", "-g", "--"]
# Set command.
CMD [ "/bin/bash" ]
