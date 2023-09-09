# vi:syntax=dockerfile
FROM debian:bullseye as builder

# upgrade and install debian packages
ENV DEBIAN_FRONTEND="noninteractive"
# fix "September 30th problem"
# https://github.com/nodesource/distributions/issues/1266#issuecomment-931597235
RUN apt-get update; apt-get install -y ca-certificates && \
    apt-get update \
    && apt-get install apt-utils -y \
    && apt-get upgrade -y \
    && apt-get install -y \
    build-essential \
    autotools-dev \
    automake \
    libtool \
    pkg-config \
    bsdmainutils \
    wget \
    && rm -rf /var/lib/apt/lists/* \
;
