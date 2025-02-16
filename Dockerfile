FROM --platform=linux/amd64 ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libgmp3-dev \
    libtinfo-dev \
    curl \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh \
    && ~/.ghcup/bin/ghcup install ghc 8.10.7 \
    && ~/.ghcup/bin/ghcup set ghc 8.10.7

ENV PATH="/root/.ghcup/bin:${PATH}"
ENV PATH="/root/.local/bin:${PATH}"

CMD ["/bin/bash"]
