# LORIS_SOURCE can be either "release" or "git".
# If "release", LORIS_VERSION refers to the release version.
# If "git", pulls from HEAD.
ARG LORIS_SOURCE="release"

FROM mysql:latest AS base

LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ENV TZ="America/New_York"
ARG LORIS_VERSION
ENV LORIS_VERSION=${LORIS_VERSION:-26.0.0}
ENV LORIS_VERSION_TAG=v${LORIS_VERSION}

FROM base AS loris-release
ADD https://github.com/aces/Loris/archive/refs/tags/v${LORIS_VERSION}.tar.gz /opt
RUN tar -xzf /opt/v${LORIS_VERSION}.tar.gz -C /opt
RUN mv /opt/Loris-${LORIS_VERSION} /opt/loris

FROM base AS loris-git
ADD --chown=lorisadmin:lorisadmin https://github.com/aces/Loris.git /opt/loris

FROM loris-${LORIS_SOURCE} AS loris
RUN mv /opt/loris/SQL/0000*.sql /docker-entrypoint-initdb.d