ARG NWN_VERSION="8193.34"
ARG NASHER_VERSION="0.16.1"
# nwnsc compiler
FROM urothis/nwnee-community-images:nwnsc-${NWN_VERSION} as nwnsc
# nwn files
FROM beamdog/nwserver:${NWN_VERSION} AS nwn
# nasher image
FROM debian:bullseye
COPY --from=nwnsc usr/local/bin/nwnsc usr/local/bin/nwnsc
COPY --from=nwn /nwn/data /nwn/data
ENV NWN_ROOT=/nwn/data
ENV PATH=/root/.nimble/bin:$PATH
RUN apt update && apt install curl gcc git sqlite3 git wget xz-utils -y && \
  curl https://nim-lang.org/choosenim/init.sh -sSf > /tmp/init.sh; sh /tmp/init.sh -y; rm /tmp/init.sh && \
  nimble install nasher@#${NASHER_VERSION} -y && \
  bash -c "mkdir -pv /nasher/install/{erf,hak,modules,tlk}" && \
  rm -rf /var/lib/apt/lists/*
WORKDIR /nasher
ENTRYPOINT [ "nasher" ]
CMD [ "--help" ]
