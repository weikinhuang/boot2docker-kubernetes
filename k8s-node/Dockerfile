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

# default env variables
ARG KUBERNETES_VERSION=v1.7.5
ENV KUBERNETES_VERSION $KUBERNETES_VERSION

ARG BOOTKUBE_IMAGE_URL=quay.io/coreos/bootkube
ARG BOOTKUBE_IMAGE_TAG=v0.6.2
ENV BOOTKUBE_IMAGE_URL $BOOTKUBE_IMAGE_URL
ENV BOOTKUBE_IMAGE_TAG $BOOTKUBE_IMAGE_TAG

ARG HYPERKUBE_IMAGE_URL=quay.io/coreos/hyperkube
ARG HYPERKUBE_IMAGE_TAG=v1.7.5_coreos.0
ENV HYPERKUBE_IMAGE_URL $HYPERKUBE_IMAGE_URL
ENV HYPERKUBE_IMAGE_TAG $HYPERKUBE_IMAGE_TAG

RUN set -x \
    && mkdir -p /data \
    && echo "KUBERNETES_VERSION=${KUBERNETES_VERSION}" > /data/k8s.env \
    && echo "BOOTKUBE_IMAGE_URL=${BOOTKUBE_IMAGE_URL}" >> /data/k8s.env \
    && echo "BOOTKUBE_IMAGE_TAG=${BOOTKUBE_IMAGE_TAG}" >> /data/k8s.env \
    && echo "HYPERKUBE_IMAGE_URL=${HYPERKUBE_IMAGE_URL}" >> /data/k8s.env \
    && echo "HYPERKUBE_IMAGE_TAG=${HYPERKUBE_IMAGE_TAG}" >> /data/k8s.env

COPY container/ /

RUN set -x \
    && systemctl enable kubelet.path \
    && systemctl enable kubeconfig.path
