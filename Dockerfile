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
    openssl-dev \
    meson \
    ninja \
    vala \
    pkgconf \
    glib-dev \
    libusb-dev \
    nodejs \
    npm \
    bc \
    procps && \
    rm -rf /var/cache/apk/*

# Install Android SDK Platform-Tools (adb, fastboot) - aapt is part of this
# This will install aapt (aapt/aapt2 are in the 'build-tools' directory of the SDK)
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/platform-tools"
RUN wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O /tmp/platform-tools-latest-linux.zip && \
    unzip /tmp/platform-tools-latest-linux.zip -d ${ANDROID_SDK_ROOT} && \
    rm /tmp/platform-tools-latest-linux.zip

# To get aapt, we need Android SDK Build-Tools. This is usually large,
# but can be obtained by installing a specific version of build-tools.
# Let's try to download a recent one and extract aapt.
# Find a suitable version from https://developer.android.com/tools/releases/build-tools
ENV ANDROID_BUILD_TOOLS_VERSION="34.0.0" # Example version, choose a stable one
RUN wget https://dl.google.com/android/repository/build-tools_r${ANDROID_BUILD_TOOLS_VERSION}-linux.zip -O /tmp/build-tools.zip && \
    unzip /tmp/build-tools.zip -d ${ANDROID_SDK_ROOT}/build-tools/ && \
    mv ${ANDROID_SDK_ROOT}/build-tools/${ANDROID_BUILD_TOOLS_VERSION} ${ANDROID_SDK_ROOT}/build-tools/latest && \
    rm /tmp/build-tools.zip
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/build-tools/latest"


# Install Apktool (already handled, keeping it for completeness)
# Apktool requires Java, which is already installed above (openjdk17-jre-headless)
# Check https://apktool.org/ for the latest version
ENV APKTOOL_VERSION=2.9.3
RUN wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_${APKTOOL_VERSION}.jar -O /usr/local/bin/apktool.jar && \
    echo '#!/usr/bin/env sh\njava -jar /usr/local/bin/apktool.jar "$@"' > /usr/local/bin/apktool && \
    chmod +x /usr/local/bin/apktool

# Install Smali/Baksmali (often bundled with Apktool, or from JesusFreke's GitHub)
# Apktool uses smali/baksmali internally, but if you need direct CLI access:
ENV SMALI_VERSION="2.5.2" # Check https://github.com/JesusFreke/smali/releases for latest
RUN wget https://github.com/JesusFreke/smali/releases/download/v${SMALI_VERSION}/smali-${SMALI_VERSION}.jar -O /usr/local/bin/smali.jar && \
    wget https://github.com/JesusFreke/smali/releases/download/v${SMALI_VERSION}/baksmali-${SMALI_VERSION}.jar -O /usr/local/bin/baksmali.jar && \
    echo '#!/usr/bin/env sh\njava -jar /usr/local/bin/smali.jar "$@"' > /usr/local/bin/smali && \
    echo '#!/usr/bin/env sh\njava -jar /usr/local/bin/baksmali.jar "$@"' > /usr/local/bin/baksmali && \
    chmod +x /usr/local/bin/smali /usr/local/bin/baksmali


# Install Dex2jar
ENV DEX2JAR_VERSION="2.1" # Check https://github.com/pxb1988/dex2jar/releases for latest
RUN wget https://github.com/pxb1988/dex2jar/releases/download/${DEX2JAR_VERSION}/dex2jar-${DEX2JAR_VERSION}.zip -O /tmp/dex2jar.zip && \
    unzip /tmp/dex2jar.zip -d /opt/dex2jar && \
    rm /tmp/dex2jar.zip && \
    chmod +x /opt/dex2jar/dex2jar-${DEX2JAR_VERSION}/*.sh && \
    ln -s /opt/dex2jar/dex2jar-${DEX2JAR_VERSION}/*.sh /usr/local/bin/ # Create symlinks for easier access


# Install Jadx
ENV JADX_VERSION="1.4.0" # Check https://github.com/skylot/jadx/releases for latest CLI-only version
RUN wget https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip -O /tmp/jadx.zip && \
    unzip /tmp/jadx.zip -d /opt/jadx && \
    rm /tmp/jadx.zip && \
    chmod +x /opt/jadx/bin/jadx && \
    ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx # Create symlink for easier access


# Install Frida tools
RUN pip3 install --no-cache-dir frida-tools --break-system-packages

# Install frida-gadget (Pypi package for patching)
RUN pip3 install --no-cache-dir frida-gadget --break-system-packages

# Copy binary to production image
COPY --from=builder /app/start.sh /app/start.sh
COPY --from=builder /app/my-app /app/my-app
COPY --from=tailscale /app/tailscaled /app/tailscaled
COPY --from=tailscale /app/tailscale /app/tailscale

RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Run on container startup.
CMD ["/app/start.sh"]
