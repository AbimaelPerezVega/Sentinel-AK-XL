FROM ubuntu:22.04

# Set timezone to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    cron \
    rsyslog \
    curl \
    jq \
    netcat \
    vim \
    net-tools \
    procps \
    wget \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Wazuh agent
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && \
    chmod 644 /usr/share/keyrings/wazuh.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list && \
    apt-get update && \
    WAZUH_MANAGER='172.20.0.13' apt-get install -y wazuh-agent

# Create directories
RUN mkdir -p /opt/sysmon-simulator/{scripts,configs,logs}

# Copy application files
COPY scripts/ /opt/sysmon-simulator/scripts/
COPY configs/ /opt/sysmon-simulator/configs/

# Set permissions
RUN chmod +x /opt/sysmon-simulator/scripts/*.py

# Create log file
RUN touch /var/log/sysmon-simulator.log
RUN chmod 644 /var/log/sysmon-simulator.log

# Copy and set entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose Wazuh agent port
EXPOSE 1514

WORKDIR /opt/sysmon-simulator

ENTRYPOINT ["/entrypoint.sh"]
