FROM curlimages/curl:7.80.0 as downloader
ENV OC_VERSION 4.6.32
ENV OC_SHA256 eff8fece7098937c922ff70ef2d8c2abff516bd871244708d0225f3d24c7303d
ENV OC_URL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux-${OC_VERSION}.tar.gz"
ENV YQ_VERSION 4.16.1
ENV YQ_SHA512 a40f46aa7c5620162ee297aa4a06863c9ed3008037f392c102b1f78e2c38a0115872aaabd8e8c85c5a0b3a3b47451d8d9bb198042c533916cfb8ae62d595e4d5
ENV USERNAME=osyb
ENV BASE=/opt/${USERNAME}
WORKDIR /tmp
COPY osyb .
USER root
RUN echo "Downloading ${OC_URL}" && \
    curl -sL "${OC_URL}" > oc.tar.gz && \
    echo "${OC_SHA256}  oc.tar.gz" | sha256sum -c && \
    tar zxvf /tmp/oc.tar.gz && \
    curl -sL https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 > yq && \
    sha512sum /tmp/yq && \
    echo "${YQ_SHA512}  yq" | sha512sum -c && \
    curl -sL https://raw.githubusercontent.com/trivento/scripts/main/openshift/openshift-docker-user-entrypoint.sh > entrypoint.sh && \
    curl -sL https://raw.githubusercontent.com/trivento/scripts/main/openshift/openshift-docker-user.sh > user.sh && \
    chmod +x oc yq user.sh && \
    ./user.sh

FROM alpine:3.15.0
ENV BIN=/usr/local/bin/
ENV USERNAME=osyb
ENV BASE=/opt/${USERNAME}
ENV BASE_BIN=${BASE}/bin
ENV PATH=${BASE_BIN}:${PATH}
COPY --from=downloader /tmp/oc /tmp/yq $BIN
COPY --from=downloader /etc/passwd /etc/passwd
COPY --from=downloader /opt/ /opt/
RUN apk add --update --no-cache \
    curl && \
    ls -ltr /opt | grep $USERNAME | grep "\-\-\-rwx\-\-\-" && \
    ls /opt | wc -l | grep "^1$" && \
    # https://git-secret.io/installation
    sh -c "echo 'https://gitsecret.jfrog.io/artifactory/git-secret-apk/all/main'" >> /etc/apk/repositories && \
    curl 'https://gitsecret.jfrog.io/artifactory/api/security/keypair/public/repositories/git-secret-apk' > /etc/apk/keys/git-secret-apk.rsa.pub && \
    apk add --update --no-cache \
    # libc6-compat is required by oc in order to start:
    # * sh: oc: not found
    libc6-compat \
    bash \
    findutils \
    git \
    openssh \
    py-pip \
    git-secret && \
    git-secret --version && \
    pip3 install --upgrade --no-cache-dir \
    pip \
    yamllint==1.20.0
USER $USERNAME
WORKDIR $BASE
ENTRYPOINT ["entrypoint.sh"]
CMD ["osyb"]
