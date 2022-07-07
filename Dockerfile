FROM ubuntu:20.04 as builder

ENV DEBIAN_FRONTEND=noninteractive

ENV PROTOC_VERSION=21.2
ENV BUFBUILD_VERSION=1.6.0
ENV PROTOC_GEN_GO_VERSION=1.28.0
ENV PGV_VERSION=0.6.7
ENV GRPC_VERSION=1.47.0
ENV PROTOC_GEN_GO_GRPC_VERSION=1.2.0
ENV PROTOC_GEN_GRPC_JAVA_VERSION=1.47.0

ENV NODEJS_VERSION=16.15.1

# make -j || make -j || make -j is tricky for memory exhausted
RUN set -xeu; \
    mkdir -p /build; \
    cd /build; \
    apt-get update; \
    apt-get install -y curl xz-utils make git zip cmake build-essential autoconf libtool pkg-config lib32stdc++6; \
    curl -OL https://go.dev/dl/go1.18.3.linux-amd64.tar.gz; \
    rm -rf /usr/local/go; \
    tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz; \
    export PATH=$PATH:/usr/local/go/bin:/root/go/bin; \
    go version; \
    curl -OL https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz; \
    tar -xf node-v${NODEJS_VERSION}-linux-x64.tar.xz; \
    mv node-v${NODEJS_VERSION}-linux-x64 /usr/local/nodejs; \
    export PATH=$PATH:/usr/local/nodejs/bin; \
    node --version; \
    npm i --location=global prettier prettier-plugin-java; \
    go install github.com/bufbuild/buf/cmd/buf@v${BUFBUILD_VERSION}; \
    go install github.com/envoyproxy/protoc-gen-validate@v${PGV_VERSION}; \
    go install google.golang.org/protobuf/cmd/protoc-gen-go@v${PROTOC_GEN_GO_VERSION}; \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v${PROTOC_GEN_GO_GRPC_VERSION}; \
    go install golang.org/x/tools/cmd/goimports@latest; \
    curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip; \
    unzip protoc-${PROTOC_VERSION}-linux-x86_64.zip -d /usr/local/protoc/; \
    export PATH=$PATH:/usr/local/protoc/bin; \
    curl -OL https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/${PROTOC_GEN_GRPC_JAVA_VERSION}/protoc-gen-grpc-java-${PROTOC_GEN_GRPC_JAVA_VERSION}-linux-x86_64.exe; \
    mv protoc-gen-grpc-java-${PROTOC_GEN_GRPC_JAVA_VERSION}-linux-x86_64.exe /usr/bin/protoc-gen-grpc-java; \
    chmod +x /usr/bin/protoc-gen-grpc-java; \
    git clone --recurse-submodules -b v${GRPC_VERSION} --depth 1 --shallow-submodules https://github.com/grpc/grpc; \
    cd grpc; \
    mkdir -p cmake/build; \
    cd cmake/build; \
    cmake -DgRPC_INSTALL=ON \
          -DgRPC_BUILD_TESTS=OFF \
          -DCMAKE_INSTALL_PREFIX=/build/bin \
          ../..; \
    make -j || make -j || make -j; \
    make install; \
    cd /build;

FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y clang-format git make

COPY --from=builder /usr/local/protoc /usr/local/protoc
COPY --from=builder /usr/local/nodejs /usr/local/nodejs
COPY --from=builder /root/go/bin/buf \
                    /root/go/bin/protoc-gen-validate \
                    /root/go/bin/protoc-gen-go \
                    /root/go/bin/protoc-gen-go-grpc \
                    /usr/bin/protoc-gen-grpc-java \
                    /build/bin/bin/grpc_cpp_plugin \
                    /root/go/bin/goimports \
                    /usr/local/go/bin/gofmt \
                    /usr/bin/

ENV PATH="$PATH:/usr/local/protoc/bin:/usr/local/nodejs/bin"

RUN set -xeu; \
    git --version; \
    buf --version; \
    protoc --version; \
    prettier --version; \
    clang-format --version; \
    which protoc-gen-go; \
    which protoc-gen-go-grpc; \
    which protoc-gen-grpc-java; \
    which grpc_cpp_plugin; \
    which protoc-gen-validate; \
    which gofmt; \
    which goimports;
