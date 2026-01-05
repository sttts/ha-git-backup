ARG BUILD_FROM
FROM $BUILD_FROM

# Install git, openssh-client, jq, inotify-tools, and python for web UI
RUN apk add --no-cache \
    git \
    openssh-client \
    jq \
    bash \
    rsync \
    tzdata \
    inotify-tools \
    python3 \
    py3-pip

# Copy root filesystem
COPY rootfs /

# Make scripts executable
RUN chmod a+x /run.sh

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Labels
LABEL \
    io.hass.name="Git Config Backup" \
    io.hass.description="Automatically backup Home Assistant configuration to Git" \
    io.hass.type="addon" \
    io.hass.version="1.0.0"

CMD [ "/run.sh" ]
