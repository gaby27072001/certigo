FROM node:20.20.2-bookworm-slim@sha256:3d0f05455dea2c82e2f76e7e2543964c30f6b7d673fc1a83286736d44fe4c41c

ARG RUNNER_VERSION=2.336.0
ARG RUNNER_SHA256=04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d

LABEL org.opencontainers.image.source="https://github.com/gchambaud_microsoft/Certigo"
LABEL org.opencontainers.image.description="Ephemeral, identity-free Certigo PR runner for ACA Jobs"
LABEL org.opencontainers.image.version="${RUNNER_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_HOME=/home/runner/actions-runner
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gzip \
      jq \
      libicu72 \
      libkrb5-3 \
      libssl3 \
      python3 \
      python3-pip \
      tar \
      tini \
      unzip \
      xz-utils \
      zip \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1001 --shell /bin/bash runner \
    && install -d -o runner -g runner "${RUNNER_HOME}" "${RUNNER_TOOL_CACHE}" /opt/certigo \
    && curl --fail --silent --show-error --location --retry 3 \
      --output /tmp/actions-runner.tar.gz \
      "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && echo "${RUNNER_SHA256}  /tmp/actions-runner.tar.gz" | sha256sum --check --strict \
    && tar --extract --gzip --file /tmp/actions-runner.tar.gz --directory "${RUNNER_HOME}" \
    && rm --force /tmp/actions-runner.tar.gz \
    && chown -R runner:runner "${RUNNER_HOME}" "${RUNNER_TOOL_CACHE}"

COPY --chown=runner:runner prepare-jit.mjs /opt/certigo/prepare-jit.mjs
COPY --chown=runner:runner run-ephemeral.sh /opt/certigo/run-ephemeral.sh

RUN chmod 0555 /opt/certigo/prepare-jit.mjs /opt/certigo/run-ephemeral.sh

USER runner
WORKDIR /home/runner/actions-runner

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/certigo/run-ephemeral.sh"]
