# vi:syntax=dockerfile

FROM golang:1.18-bullseye as muslstack

# upgrade and install debian packages
ENV DEBIAN_FRONTEND="noninteractive"
# fix "September 30th problem"
# https://github.com/nodesource/distributions/issues/1266#issuecomment-931597235
RUN apt-get update; apt-get install -y ca-certificates && \
    apt-get update \
    && apt-get install apt-utils -y \
    && apt-get upgrade -y \
    && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/* \
;
WORKDIR /usr/src
RUN git clone https://github.com/yaegashi/muslstack.git
WORKDIR /usr/src/muslstack
RUN git checkout d19cc5866abce3ca59dfc1666df7cc97097d0933 && go build main.go


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
    git \
    curl \
    && rm -rf /var/lib/apt/lists/* \
;

ENV DOGE_VERSION=v1.14.6
ENV DOGE_ROOT=/usr/src/dogecoin
ENV MUSL_CROSS_ROOT=/usr/src/musl-cross-make
ENV MUSL_CROSS_COMMIT=fe915821b652a7fa37b34a596f47d8e20bc72338
WORKDIR /usr/src

# configure git for patching with am
RUN git config --global user.email "dogecoin@example.com"
RUN git config --global user.name "Doge"

# download musl-cross-make source code
RUN mkdir -p ${MUSL_CROSS_ROOT}/..
WORKDIR ${MUSL_CROSS_ROOT}/..
RUN git clone https://github.com/richfelker/musl-cross-make.git ${MUSL_CROSS_ROOT}

# switch to musl-cross-make source code and checkout the commit hash
WORKDIR ${MUSL_CROSS_ROOT}
RUN git checkout ${MUSL_CROSS_COMMIT} -b tmpbuildenv && git clean -fdx

# copy over and apply musl-cross-make patches
COPY ./musl-cross-make-patches ./doge-patches
RUN set -x \
    && git apply ./doge-patches/*.diff \
    && git am ./doge-patches/*.patch \
;

# compile musl-cross-make
RUN make TARGET=$(uname -m)-linux-musl install -j$(nproc)

# download DOGE source code
RUN mkdir -p ${DOGE_ROOT}/..
WORKDIR ${DOGE_ROOT}/..
RUN git clone https://github.com/dogecoin/dogecoin.git ${DOGE_ROOT}

# switch to the DOGE source code directory on the tagged version
WORKDIR ${DOGE_ROOT}
RUN git checkout "tags/${DOGE_VERSION}" -b tmpbuildenv && git clean -fdx

# copy over and apply patches
COPY ./patches ./patches
RUN git apply patches/*.diff

# build dependencies
RUN cd depends && make -j$(nproc) NO_QT=1 USE_MUSL_LIBC=1 HOST=$(uname -m)-linux-musl

# build doge
RUN ./autogen.sh
RUN CONFIG_SITE=$(pwd)/depends/$(uname -m)-linux-musl/share/config.site ./configure --enable-reduce-exports --enable-lto LDFLAGS="-Wl,-O2" LIBTOOL_APP_LDFLAGS="-all-static"
RUN make -j$(nproc)

# install doge
RUN make install

# patch doge binaries
COPY --from=muslstack /usr/src/muslstack/main /usr/local/bin/muslstack
RUN set -x \
    && muslstack -s 0x900000 /usr/local/bin/dogecoind \
    && muslstack -s 0x900000 /usr/local/bin/dogecoin-cli \
    && muslstack -s 0x900000 /usr/local/bin/dogecoin-tx \
    && muslstack -s 0x900000 /usr/local/bin/test_dogecoin \
    && muslstack -s 0x900000 /usr/local/bin/bench_dogecoin \
;

# final stage output image
FROM amazonlinux:2
RUN yum update -y && \
    yum install -y \
        shadow-utils \
        rsync \
 && yum clean all \
 && rm -rf /var/cache/yum \
;

# non-root user
ENV USER=doge
ENV HOME /home/$USER
RUN adduser -m -d $HOME $USER
WORKDIR $HOME
USER $USER

# copy in staticly-compiled binaries from builder
COPY --from=builder /usr/local/bin/dogecoind /usr/local/bin/dogecoind
COPY --from=builder /usr/local/bin/dogecoin-cli /usr/local/bin/dogecoin-cli
COPY --from=builder /usr/local/bin/dogecoin-tx /usr/local/bin/dogecoin-tx
COPY --from=builder /usr/local/bin/test_dogecoin /usr/local/bin/test_dogecoin
COPY --from=builder /usr/local/bin/bench_dogecoin /usr/local/bin/bench_dogecoin

# dogecoind as entrypoint (could replace this with a script later)
ENTRYPOINT ["/usr/local/bin/dogecoind"]
