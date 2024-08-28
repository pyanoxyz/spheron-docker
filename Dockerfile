FROM --platform=linux/amd64 ubuntu:latest
# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /home/llama

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Set execute permissions
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose the port used by the server
EXPOSE 52555

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
