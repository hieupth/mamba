ARG UBUNTU_VERSION=noble
ARG PACKAGES


FROM ubuntu:${UBUNTU_VERSION}
# Recall build args.
ARG PACKAGES
ARG TARGETARCH
# Useful envinronment.
ENV DEBIAN_FRONTEND=noninteractive
# Image metadata.
LABEL org.opencontainers.image.title="mamba" \
    org.opencontainers.image.description="Minimal Ubuntu-based image with Miniforge" \
    org.opencontainers.image.source=https://github.com/hieupth/mamba \
    org.opencontainers.image.licenses=Apache-2.0
# Install required packages.
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
        curl \
        gnupg \
        ca-certificates \
        tini \
        git \
        # Additional packages.
        ${PACKAGES} && \
    # Clean cache.
    apt-get clean && rm -rf /var/lib/apt/lists/*
# Set conda environments.
ENV CONDA_DIR=/opt/conda
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=${CONDA_DIR}/bin:${PATH}
# Install latest miniforge.
RUN MINIFORGE_ASSET="Miniforge3-$(uname)-$(uname -m)" && \
    curl -fsSL -o "/${MINIFORGE_ASSET}.sh" "https://github.com/conda-forge/miniforge/releases/latest/download/${MINIFORGE_ASSET}.sh" && \
    chmod +x "/${MINIFORGE_ASSET}.sh" && \
    "/${MINIFORGE_ASSET}.sh" -b -p ${CONDA_DIR} && \
    rm "/${MINIFORGE_ASSET}.sh" && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
    conda clean -ay
# Additional
COPY scripts/* /usr/local/bin/
# Expose arch info to login shells.
COPY scripts/targetarch.sh /etc/profile.d/targetarch.sh
# Set tini.
ENTRYPOINT ["tini", "-g", "--"]
# Set command.
CMD ["/bin/bash"]
