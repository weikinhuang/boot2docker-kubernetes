FROM solita/ubuntu-systemd:latest

RUN set -x \
    && apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qqy \
        apt-transport-https \
        ca-certificates \
        wget \
        curl \
        iptables \
        ipcalc \
        ethtool \
        dmsetup \
        iproute2 \
        net-tools \
        iputils-ping \
        tcpdump \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qqy \
        bridge-utils \
        ipcalc \
        jq \
        liblz4-tool \
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

ENV K8S_VERSION=v1.7.5
RUN set -x \
    && curl -sSL https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/hyperkube > /usr/local/bin/hyperkube \
    && chmod +x /usr/local/bin/hyperkube

COPY container/ /

RUN set -x \
    && ln -s /etc/systemd/system/kubelet.path /etc/systemd/system/multi-user.target.wants/kubelet.path \
    && ln -s /etc/systemd/system/kubelet.service /etc/systemd/system/multi-user.target.wants/kubelet.service
