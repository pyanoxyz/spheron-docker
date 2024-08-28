# Build stage: Compile llama.cpp with CUDA support
FROM nvidia/cuda:12.5.1-devel-ubuntu22.04 AS env-build

WORKDIR /srv

# Install build tools and clone and compile llama.cpp
RUN apt-get update && apt-get install -y build-essential git libgomp1

RUN git clone https://github.com/ggerganov/llama.cpp.git \
  && cd llama.cpp \
  && make -j LLAMA_CUDA=1 CUDA_DOCKER_ARCH=all

# Deployment stage: Minimal environment with necessary libraries and binaries
FROM debian:12-slim AS env-deploy

# Copy OpenMP and CUDA libraries
ENV LD_LIBRARY_PATH=/usr/local/lib
COPY --from=env-build /usr/lib/x86_64-linux-gnu/libgomp.so.1 ${LD_LIBRARY_PATH}/libgomp.so.1
COPY --from=env-build /usr/local/cuda/lib64/libcublas.so.12 ${LD_LIBRARY_PATH}/libcublas.so.12
COPY --from=env-build /usr/local/cuda/lib64/libcublasLt.so.12 ${LD_LIBRARY_PATH}/libcublasLt.so.12
COPY --from=env-build /usr/local/cuda/lib64/libcudart.so.12 ${LD_LIBRARY_PATH}/libcudart.so.12

# Copy llama.cpp binaries
COPY --from=env-build /srv/llama.cpp/llama-cli /usr/local/bin/llama-cli
COPY --from=env-build /srv/llama.cpp/llama-server /usr/local/bin/llama-server

# Create llama user and set home directory
RUN useradd --system --create-home llama

USER llama

WORKDIR /home/llama

EXPOSE 8080

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
