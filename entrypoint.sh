#!/bin/bash

VERSION="b3609" # Change this if the version changes
INSTALL_DIR="$HOME/.pyano"
BUILD_DIR="$INSTALL_DIR/build/bin"
MODEL_DIR="$HOME/.pyano/models"
MODEL_PATH="$MODEL_DIR/$MODEL_NAME"

# Function to get system RAM in GB
get_system_ram() {
    # Linux
    ram_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
}

# Function to select model based on RAM
select_model() {
    get_system_ram
    if [ $ram_gb -lt 9 ]; then
        MODEL_NAME="Phi-3.5-mini-instruct-IQ2_M.gguf"
        MODEL_URL="https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-IQ2_M.gguf"
        CTX=2048
        BATCH_SIZE=1024
        GPU_LAYERS_OFFLOADED=16
    elif [ $ram_gb -gt 24 ]; then
        MODEL_NAME="Hermes-3-Llama-3.1-8B.Q8_0.gguf"
        MODEL_URL="https://huggingface.co/NousResearch/Hermes-3-Llama-3.1-8B-GGUF/resolve/main/Hermes-3-Llama-3.1-8B.Q8_0.gguf"
        CTX=16384
        BATCH_SIZE=4096
        GPU_LAYERS_OFFLOADED=-1
    else
        MODEL_NAME="Hermes-3-Llama-3.1-8B.Q8_0.gguf"
        MODEL_URL="https://huggingface.co/NousResearch/Hermes-3-Llama-3.1-8B-GGUF/resolve/main/Hermes-3-Llama-3.1-8B.Q8_0.gguf"
        CTX=16384
        BATCH_SIZE=2048
        GPU_LAYERS_OFFLOADED=8
    fi
    MODEL_PATH="$MODEL_DIR/$MODEL_NAME"
}

select_model

# Function to download and unzip if the version is not present
download_and_unzip() {
    # Check if curl or wget is installed and set DOWNLOAD_CMD accordingly
    if command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -Lo"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -O"
    else
        echo "Neither curl nor wget is installed. Installing curl..."
        apt-get update && apt-get install -y curl
        DOWNLOAD_CMD="curl -Lo"
    fi

    # Create the ~/.pyano/ directory if it doesn't exist
    mkdir -p $INSTALL_DIR

    # Download the appropriate file based on the OS
    if [[ ! -f "$INSTALL_DIR/$ZIP_FILE" ]]; then
        echo "Downloading $ZIP_FILE..."
        $DOWNLOAD_CMD $INSTALL_DIR/$ZIP_FILE $DOWNLOAD_URL

        # Unzip the downloaded file
        echo "Unzipping $ZIP_FILE..."
        unzip $INSTALL_DIR/$ZIP_FILE -d $INSTALL_DIR/
    else
        echo "$ZIP_FILE already exists, skipping download and unzip."
    fi
}

# Function to determine OS and set the download URL and ZIP file name
set_download_info() {
    ZIP_FILE="llama-$VERSION-bin-ubuntu-x64.zip"
    DOWNLOAD_URL="https://github.com/ggerganov/llama.cpp/releases/download/$VERSION/$ZIP_FILE"
}

# Function to check if the model file is present and download it if not
check_and_download_model() {
    # Create the model directory if it doesn't exist
    mkdir -p $MODEL_DIR

    # Check if the model file exists
    if [[ ! -f $MODEL_PATH ]]; then
        echo "Model file $MODEL_NAME not found. Downloading..."

        # Determine which download tool is available, and install wget if neither is found
        if command -v curl &> /dev/null; then
            curl -Lo $MODEL_PATH $MODEL_URL
        elif command -v wget &> /dev/null; then
            wget -O $MODEL_PATH $MODEL_URL
        else
            echo "Neither curl nor wget is installed. Installing wget..."
            apt-get update && apt-get install -y wget
            wget -O $MODEL_PATH $MODEL_URL
        fi

        echo "Model file downloaded to $MODEL_PATH."
    else
        echo "Model file $MODEL_NAME already exists in $MODEL_DIR."
    fi
}

# Function to install requirements for llama
install_requirements_llama() {
    apt-get update && apt-get install -y libgomp1
}

check_and_download_model
set_download_info
download_and_unzip
install_requirements_llama

# Calculate the number of CPU cores
get_num_cores() {
    num_cores=$(nproc)
}
get_num_cores
echo "Model being used $MODEL_PATH"
echo "Number of cores are $num_cores"

# Run the server command
$BUILD_DIR/llama-server \
  -m $MODEL_PATH \
  -n 500 \
  --ctx-size $CTX \
  --parallel 2 \
  --n-gpu-layers $GPU_LAYERS_OFFLOADED \
  --port 52555 \
  --threads $num_cores \
  --color \
  --metrics \
  --batch-size $BATCH_SIZE \
  --numa isolate \
  --mlock \
  --no-mmap \
  --conversation \
  --flash-attn \
  --cache-type-k f16 \
  --cache-type-v f16 \
  --prompt-cache-all \
  --repeat-last-n 64 \
  --repeat-penalty 1.3 \
  --top-k 40 \
  --top-p 0.9 \
  --threads-http 4
