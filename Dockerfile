FROM ubuntu:latest

ARG AUTH_KEYS_URL_ARG
ARG ZROK_TOKEN_ARG

ENV AUTH_KEYS_URL=$AUTH_KEYS_URL_ARG
ENV ZROK_TOKEN=$ZROK_TOKEN_ARG
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages in a single layer
RUN apt-get update && apt-get install -y \
    openssh-server \
    wget \
    curl \
    git \
    sudo \
    zsh \
    vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create required directories
RUN mkdir -p /kaggle/working

# Set up working directory
WORKDIR /tmp/kagglelink

# Copy repository files
COPY . .

# Make scripts executable
RUN chmod +x setup_kaggle_zrok.sh \
    install_extensions.sh \
    test_all.sh \
    start_zrok.sh

# Default command to run tests or you can override with bash
CMD ["./test_all.sh"]
# Alternatively: CMD ["bash"]
