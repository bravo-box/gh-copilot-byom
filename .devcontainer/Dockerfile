FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Install Terraform
RUN apt-get update && apt-get install -y \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Add HashiCorp GPG key and repository
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
RUN apt-get update && apt-get install -y \
    terraform \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    apt-transport-https \
    lsb-release \
    gnupg \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
    && echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update \
    && apt-get install -y azure-cli \
    && rm -rf /var/lib/apt/lists/*

# Verify installations
RUN terraform version && az --version
