ARG BASE=hieupth/mamba
ARG CUDA=12.8.0
ARG CUDNN=9.8.0

FROM ${BASE}
#
ARG CUDA
ARG CUDNN 
#
RUN mamba install -c nvidia \
      cuda-toolkit=${CUDA} cuda-nvcc libcublas cudnn=${CUDNN} nccl && \
    mamba clean -ay 