ARG BASE=ubuntu:22.04
ARG MINIFORGE_NAME=Mambaforge

FROM ${BASE}
# Recall build args.
ARG MINIFORGE_NAME
# Disable interactive mode.
ENV DEBIAN_FRONTEND=noninteractive
# Install required packages.
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
        wget \
        curl \
        tini \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# Set envs.
ENV CONDA_DIR=/opt/conda
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=${CONDA_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CONDA_DIR}/lib:${LD_LIBRARY_PATH}
# Install mambaforge.
RUN curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/${MINIFORGE_NAME}-$(uname)-$(uname -m).sh && \
    chmod +x /${MINIFORGE_NAME}-$(uname)-$(uname -m).sh && \
    /${MINIFORGE_NAME}-$(uname)-$(uname -m).sh -b -p ${CONDA_DIR} && \
    rm /${MINIFORGE_NAME}-$(uname)-$(uname -m).sh && \
    conda clean -tipy && \
    find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
    find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
    conda clean -ay
# Set tini.
ENTRYPOINT ["tini", "-g", "--"]
# Set command.
CMD [ "/bin/bash" ]
