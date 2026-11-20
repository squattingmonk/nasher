ARG NWSERVER_IMAGE=urothis/nwserver:stable
ARG NWDATA_PATH=/nwn

# nw data source
FROM $NWSERVER_IMAGE as nwserver

# nwnsc compiler
FROM nwneetools/nwnsc:latest as nwnsc

# nim image
FROM nimlang/nim:latest as nasher
ARG NWDATA_PATH
COPY --from=nwnsc /usr/local/bin/nwnsc /usr/local/bin/nwnsc
COPY --from=nwserver $NWDATA_PATH /nwn
ENV NWN_ROOT=/nwn/data
RUN dpkg --add-architecture i386 \
    && apt update \
    && apt upgrade -y \
    && apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386 libsqlite3-0 -y \
    && rm -fr /var/lib/apt/lists/* /root/.cache/* /usr/share/doc/* /var/cache/man/*
ARG NASHER_USER_ID=1000
RUN adduser nasher --disabled-password --gecos "" --uid ${NASHER_USER_ID}
RUN echo "nasher ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && usermod -aG sudo nasher
WORKDIR /nasher
RUN chown -R nasher:nasher /nwn /usr/local/bin/nwnsc /nasher
USER nasher
ENV PATH="/home/nasher/.nimble/bin:$PATH"
# Build nasher from the source in the build context so the image always matches
# the checked-out version (no need to bump a version here on each release).
COPY --chown=nasher:nasher . /home/nasher/src
RUN cd /home/nasher/src \
    && nimble install -y \
    && cd / \
    && rm -rf /home/nasher/src
RUN chmod +x /home/nasher/.nimble/bin/nasher
RUN nasher config --installDir:"/nasher/install" \
    && nasher config --userName:"nasher"
WORKDIR /nasher
RUN bash -c "mkdir -pv /nasher/install/{erf,hak,modules,tlk}"
ENTRYPOINT [ "nasher" ]
CMD [ "--help" ]
