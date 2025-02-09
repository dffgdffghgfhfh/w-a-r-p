FROM ubuntu:22.04
# 设置默认平台为 linux/amd64
ARG TARGETPLATFORM=linux/amd64

ARG WARP_VERSION
ARG GOST_VERSION
ARG COMMIT_SHA
ARG TARGETPLATFORM

LABEL org.opencontainers.image.authors="cmj2002"
LABEL org.opencontainers.image.url="https://github.com/cmj2002/warp-docker"
LABEL WARP_VERSION=${WARP_VERSION}
LABEL GOST_VERSION=${GOST_VERSION}
LABEL COMMIT_SHA=${COMMIT_SHA}

# 调试：输出 TARGETPLATFORM 的值
RUN echo "TARGETPLATFORM is: ${TARGETPLATFORM}"

COPY entrypoint.sh /entrypoint.sh
COPY ./healthcheck /healthcheck

# 增加更多调试信息，确保 ARCH 变量正确赋值
RUN echo "GOST_VERSION is: ${GOST_VERSION}" && \
    echo "TARGETPLATFORM is: ${TARGETPLATFORM}" && \
    echo "Before setting ARCH: ${ARCH}" && \
    case ${TARGETPLATFORM} in \
      "linux/amd64") export ARCH="amd64" ;; \
      "linux/arm64") export ARCH="arm64" ;; \
      "linux/arm/v7") export ARCH="armv7" ;; \
      *) export ARCH="unknown" ;; \
    esac && \
    echo "After setting ARCH: ${ARCH}" && \
    if [ -z "${ARCH}" ]; then \
      echo "Error: ARCH is not set correctly!" && \
      exit 1; \
    fi && \
    echo "Building for ${TARGETPLATFORM} with GOST ${GOST_VERSION}" && \
    MAJOR_VERSION=$(echo ${GOST_VERSION} | cut -d. -f1) && \
    MINOR_VERSION=$(echo ${GOST_VERSION} | cut -d. -f2) && \
    if [ "${MAJOR_VERSION}" -ge 3 ] || [ "${MAJOR_VERSION}" -eq 2 -a "${MINOR_VERSION}" -ge 12 ]; then \
      NAME_SYNTAX="new" && \
      FILE_NAME="gost_${GOST_VERSION}_linux_${ARCH}.tar.gz"; \
    else \
      NAME_SYNTAX="legacy" && \
      FILE_NAME="gost-linux-${ARCH}-${GOST_VERSION}.gz"; \
    fi && \
    echo "File name: ${FILE_NAME}" && \
    curl -LO https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/${FILE_NAME} && \
    if [ "${NAME_SYNTAX}" = "new" ]; then \
      tar -xzf ${FILE_NAME} -C /usr/bin/ gost; \
    else \
      gunzip ${FILE_NAME} && \
      mv gost-linux-${ARCH}-${GOST_VERSION} /usr/bin/gost; \
    fi && \
    chmod +x /usr/bin/gost && \
    chmod +x /entrypoint.sh && \
    chmod +x /healthcheck/index.sh && \
    useradd -m -s /bin/bash warp && \
    echo "warp ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/warp

USER warp

# Accept Cloudflare WARP TOS
RUN mkdir -p /home/warp/.local/share/warp && \
    echo -n 'yes' > /home/warp/.local/share/warp/accepted-tos.txt

ENV GOST_ARGS="-L :1080"
ENV WARP_SLEEP=2
ENV REGISTER_WHEN_MDM_EXISTS=
ENV WARP_LICENSE_KEY=
ENV BETA_FIX_HOST_CONNECTIVITY=
ENV WARP_ENABLE_NAT=

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD /healthcheck/index.sh

ENTRYPOINT ["/entrypoint.sh"]
