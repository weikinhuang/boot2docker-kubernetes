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
        jq \
        net-tools \
        socat \
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
ARG KUBERNETES_VERSION=v1.7.7
ENV KUBERNETES_VERSION $KUBERNETES_VERSION

ARG BOOTKUBE_IMAGE_URL=quay.io/coreos/bootkube
ARG BOOTKUBE_IMAGE_TAG=v0.7.0
ENV BOOTKUBE_IMAGE_URL $BOOTKUBE_IMAGE_URL
ENV BOOTKUBE_IMAGE_TAG $BOOTKUBE_IMAGE_TAG

ARG HYPERKUBE_IMAGE_URL=quay.io/coreos/hyperkube
ARG HYPERKUBE_IMAGE_TAG=${KUBERNETES_VERSION}_coreos.0
ENV HYPERKUBE_IMAGE_URL $HYPERKUBE_IMAGE_URL
ENV HYPERKUBE_IMAGE_TAG $HYPERKUBE_IMAGE_TAG

# Image used to run setup host for systemd in docker
ENV SYSTEMD_SETUP_IMAGE solita/ubuntu-systemd:latest

# install (latest) kubectl
RUN set -x \
    && curl -sSL --fail https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl > /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# add file base
COPY container/ /

# enable docker & kubelet
RUN set -x \
    && systemctl enable docker.service \
    && systemctl enable kubelet.path \
    && systemctl enable import-saved-images.service

# docker files should avoid the overlay when possible
VOLUME /var/lib/docker

ENTRYPOINT ["docker-entrypoint.sh"]
# Workaround for docker/docker#27202, technique based on comments from docker/docker#9212
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
