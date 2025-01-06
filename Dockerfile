FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl git jq python3 python3-pip python3-venv wget yq

ENV PATH=/root/.cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
 && cargo install parquet2json

ENV VIRTUAL_ENV=.venv
ENV PATH=/$VIRTUAL_ENV/bin:$PATH
RUN python3 -m venv $VIRTUAL_ENV \
 && pip3 install 'bmdf>=0.4.0' 'dffs>=0.0.5'

SHELL ["/bin/bash", "-c"]

ENV PATH=/src:$PATH
WORKDIR /src

COPY . .
RUN echo "*.parquet diff=parquet" > .gitattributes
RUN git config diff.parquet.command git-diff-parquet.sh
RUN git config diff.parquet.textconv "parquet2json-all -n2"
RUN git config diff.noprefix true
RUN git config alias.dxr "diff-x -R"
ENV SHELL=/bin/bash
RUN echo ". /src/.pqt-rc" >> /root/.bashrc
RUN git checkout -- .github .dockerignore Dockerfile

ENTRYPOINT [ "/bin/bash", "-ic", "mdcmd && git diff --exit-code" ]
