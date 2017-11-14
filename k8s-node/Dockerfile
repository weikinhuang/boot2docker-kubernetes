FROM debian:stretch-slim
LABEL maintainer="Wei Kin Huang"

# Install base dependencies
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
        systemd-container \
        tcpdump \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install specific Docker version
ENV DOCKER_VERSION 17.09.0~ce-0~ubuntu
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends \
        dirmngr \
        gnupg \
    \
    && export GNUPGHOME="$(mktemp -d)" \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && mkdir -p /etc/apt/sources.list.d \
    && echo "deb https://download.docker.com/linux/ubuntu xenial stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qqy \
        docker-ce=${DOCKER_VERSION} \
    \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false \
        dirmngr \
        gnupg \
    && rm -r "$GNUPGHOME" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# default env variables
ARG KUBERNETES_VERSION=v1.8.3
ENV KUBERNETES_VERSION $KUBERNETES_VERSION

ARG BOOTKUBE_IMAGE_URL=quay.io/coreos/bootkube
ARG BOOTKUBE_IMAGE_TAG=v0.8.2
ENV BOOTKUBE_IMAGE_URL $BOOTKUBE_IMAGE_URL
ENV BOOTKUBE_IMAGE_TAG $BOOTKUBE_IMAGE_TAG

ARG HYPERKUBE_IMAGE_URL=gcr.io/google_containers/hyperkube
ARG HYPERKUBE_IMAGE_TAG=${KUBERNETES_VERSION}
ENV HYPERKUBE_IMAGE_URL $HYPERKUBE_IMAGE_URL
ENV HYPERKUBE_IMAGE_TAG $HYPERKUBE_IMAGE_TAG

# Tell systemd that it's running in a container environment
ENV container docker

# Don't start any optional services except for the few we need.
RUN set -x \
    && find \
        /etc/systemd/system \
        /lib/systemd/system \
        -path '*.wants/*' \
        -not -name '*journald*' \
        -not -name '*systemd-tmpfiles*' \
        -not -name '*systemd-user-sessions*' \
        -exec rm \{} \;

# install (latest) kubectl
RUN set -x \
    && curl -sSL --fail https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl > /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# add file base
COPY container/ /

# enable docker & kubelet
RUN set -x \
    && systemctl set-default multi-user.target \
    && systemctl enable docker.service \
    && systemctl enable kubelet.path \
    && systemctl enable import-saved-images.service

# docker files should avoid the overlay when possible
VOLUME /var/lib/docker

# fix issues with running /var/lib/kubelet under aufs
# Fail to get rootfs information failed to get device for dir "/var/lib/kubelet": could not find device with major: 0, minor: 45 in cached partitions map
# @see https://github.com/kubernetes/kubernetes/issues/38337
RUN set -x \
    && mkdir -p /var/lib/kubelet-shared
VOLUME /var/lib/kubelet-shared

# systemd stop signal
STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["docker-entrypoint.sh"]
# Workaround for docker/docker#27202, technique based on comments from docker/docker#9212
CMD ["/bin/bash", "-c", "exec /bin/systemd --log-target=journal 3>&1"]
