FROM apache/superset

# Switch to root user
USER root

# Install Tini
ENV TINI_VERSION v0.19.0
RUN curl --silent --show-error --location --output /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 \
    && chmod +x /tini

# Install AWS CLI, Amazon SSM Agent, and additional utilities
RUN curl --silent --show-error --location --output /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
    && curl --silent --show-error --location --output /tmp/amazon-ssm-agent.deb https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/debian_amd64/amazon-ssm-agent.deb \
    && apt-get update --fix-missing \
    && apt-get install -qq -y --no-install-recommends \
       sudo \
       make \
       unzip \
       curl \
       jq \
       libpq-dev\
       python3-dev \
    && dpkg -i /tmp/amazon-ssm-agent.deb \
    && unzip /tmp/awscliv2.zip \
    && ./aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/amazon-ssm-agent.deb /var/lib/apt/lists/* \
    && usermod -aG sudo superset \
    && echo "superset ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Python requirements
COPY local_requirements.txt .
RUN pip install --no-cache-dir -r local_requirements.txt

RUN pip install --no-cache-dir psycopg2-binary

# Add and configure Superset
COPY superset_config.py /app/
ENV SUPERSET_CONFIG_PATH /app/superset_config.py

# Add entrypoint and initialization scripts
COPY /docker/superset-entrypoint.sh /app/docker/
COPY /docker/docker-bootstrap.sh /app/docker/
COPY /docker/docker-init.sh /app/docker/
COPY /docker/docker-entrypoint.sh /app/docker/

# Set execute permissions for scripts
RUN chmod +x /app/docker/*.sh

# Switch back to superset user
USER superset

# Set entrypoint
ENTRYPOINT ["/tini", "-g", "--", "/app/docker/docker-entrypoint.sh"]
