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
    bash \
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

# Define Android SDK Root
ENV ANDROID_SDK_ROOT="/opt/android-sdk"

# Install Android SDK Command-line Tools (includes sdkmanager)
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O /tmp/commandlinetools.zip && \
    unzip -q /tmp/commandlinetools.zip -d /tmp/sdk-temp && \
    mv /tmp/sdk-temp/cmdline-tools/* ${ANDROID_SDK_ROOT}/cmdline-tools/latest/ && \
    rm /tmp/commandlinetools.zip && \
    rm -rf /tmp/sdk-temp

# Now set the PATH correctly
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin"

# Accept Android SDK licenses
RUN yes | sdkmanager --licenses

# Install Android SDK Platform-Tools
RUN sdkmanager "platform-tools"

# Install Android SDK Build-Tools
ENV ANDROID_BUILD_TOOLS_VERSION="34.0.0"
RUN sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"


# Install Apktool
ENV APKTOOL_VERSION=2.9.3
RUN wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_${APKTOOL_VERSION}.jar -O /usr/local/bin/apktool.jar && \
    echo '#!/usr/bin/env sh\njava -jar /usr/local/bin/apktool.jar "$@"' > /usr/local/bin/apktool && \
    chmod +x /usr/local/bin/apktool

# =================================================================
# CORRECTED SECTION
# =================================================================
# Install Smali/Baksmali (from JesusFreke's GitHub)
# The assets are now individual JAR files, not a combined zip.
# We download them directly and create the wrappers.
ENV SMALI_VERSION="3.0.5"
RUN wget https://github.com/JesusFreke/smali/releases/download/v${SMALI_VERSION}/smali-${SMALI_VERSION}.jar -O /usr/local/bin/smali.jar && \
    wget https://github.com/JesusFreke/smali/releases/download/v${SMALI_VERSION}/baksmali-${SMALI_VERSION}.jar -O /usr/local/bin/baksmali.jar && \
    echo '#!/usr/bin/env sh\njava -jar /usr/local/bin/smali.jar "$@"' > /usr/local/bin/smali && \
    echo '#!/usr/bin/env sh\njava -jar /usr/local/bin/baksmali.jar "$@"' > /usr/local/bin/baksmali && \
    chmod +x /usr/local/bin/smali /usr/local/bin/baksmali
# =================================================================


# Install Dex2jar
ENV DEX2JAR_VERSION="2.1"
RUN wget https://github.com/pxb1988/dex2jar/releases/download/${DEX2JAR_VERSION}/dex2jar-${DEX2JAR_VERSION}.zip -O /tmp/dex2jar.zip && \
    unzip /tmp/dex2jar.zip -d /opt/dex2jar && \
    rm /tmp/dex2jar.zip && \
    chmod +x /opt/dex2jar/dex2jar-${DEX2JAR_VERSION}/*.sh && \
    ln -s /opt/dex2jar/dex2jar-${DEX2JAR_VERSION}/*.sh /usr/local/bin/


# Install Jadx
ENV JADX_VERSION="1.5.0"
RUN wget https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip -O /tmp/jadx.zip && \
    unzip /tmp/jadx.zip -d /opt/jadx && \
    rm /tmp/jadx.zip && \
    chmod +x /opt/jadx/bin/jadx && \
    ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx


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
