FROM solita/ubuntu-systemd:latest

RUN set -x \
    && apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qqy \
        apt-transport-https \
        bridge-utils \
        ca-certificates \
        curl \
        dmsetup \
        ethtool \
        ipcalc \
        iproute2 \
        iptables \
        iputils-ping \
        net-tools \
        tcpdump \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install specific Docker version
ENV DOCKER_VERSION 17.09.0~ce-0~ubuntu
RUN set -x \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && mkdir -p /etc/apt/sources.list.d \
    && echo "deb https://download.docker.com/linux/ubuntu xenial stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qqy \
        docker-ce=${DOCKER_VERSION} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# install kubectl on master
RUN set -x \
    && curl -sSL --fail https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl > /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

COPY container/ /

RUN set -x \
    && systemctl enable kubelet.path \
    && systemctl enable bootkube.service
