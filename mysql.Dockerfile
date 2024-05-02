FROM mysql:latest

LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ARG LORIS_VERSION
ENV TZ="America/New_York"

RUN mkdir -p /opt/loris
ADD https://github.com/aces/Loris/archive/refs/tags/v${LORIS_VERSION}.tar.gz /opt
RUN tar -xzf /opt/v${LORIS_VERSION}.tar.gz -C /opt/loris/ \
    && mv /opt/loris/Loris-${LORIS_VERSION}/SQL/0000*.sql /docker-entrypoint-initdb.d
