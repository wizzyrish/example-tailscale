FROM golang:1.16.2-alpine3.13 as builder
WORKDIR /app
COPY . ./
# This is where one could build the application code as well.


FROM alpine:latest as tailscale
WORKDIR /app
COPY . ./
ENV TSFILE=tailscale_1.16.2_amd64.tgz
RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1
COPY . ./


FROM alpine:latest
RUN apk update && \
    apk add --no-cache \
    ca-certificates \
    openssh \
    sudo \
    python3 \
    py3-pip \
    openjdk17-jre-headless \
    unzip \
    curl \
    git \
    build-base \
    linux-headers \
    libffi-dev \
    openssl-dev && \
    rm -rf /var/cache/apk/*

# Install Android SDK Platform-Tools (adb, fastboot)
RUN wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O /tmp/platform-tools-latest-linux.zip && \
    unzip /tmp/platform-tools-latest-linux.zip -d /opt/android-sdk && \
    rm /tmp/platform-tools-latest-linux.zip
ENV PATH="/opt/android-sdk/platform-tools:${PATH}"

# Install Apktool
# Apktool requires Java, which is already installed above (openjdk17-jre-headless)
# Check https://apktool.org/ for the latest version
ENV APKTOOL_VERSION=2.9.3
RUN wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_${APKTOOL_VERSION}.jar -O /usr/local/bin/apktool.jar && \
    echo '#!/usr/bin/env sh\njava -jar /usr/local/bin/apktool.jar "$@"' > /usr/local/bin/apktool && \
    chmod +x /usr/local/bin/apktool

# Install Frida tools
RUN pip3 install --no-cache-dir frida-tools --break-system-packages

# Install frida-gadget (this is typically distributed as a binary for specific architectures
# and would be injected into the APK, not globally installed as a Python package for direct use
# in the Docker image. However, the `frida-gadget` PyPI package helps with patching.
# If you need the actual frida-gadget binary, you'd download it from Frida's releases
# page based on your target architecture and copy it.)
# The PyPI package for frida-gadget is for a Python utility to patch APKs.)
RUN pip3 install --no-cache-dir frida-gadget --break-system-packages

# Install other useful tools for app modification
RUN apk add --no-cache \
    dex2jar \
    aapt \
    smali \
    baksmali \
    jadx \
    bc \
    procps # For utilities like pgrep, pkill often used with Frida

# Copy binary to production image
COPY --from=builder /app/start.sh /app/start.sh
COPY --from=builder /app/my-app /app/my-app
COPY --from=tailscale /app/tailscaled /app/tailscaled
COPY --from=tailscale /app/tailscale /app/tailscale

RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Run on container startup.
CMD ["/app/start.sh"]
