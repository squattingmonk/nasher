# nwnsc compiler
FROM nwneetools/nwnsc:latest as nwnsc
# nim image
FROM nimlang/choosenim:latest as nasher
COPY --from=nwnsc usr/local/bin/nwnsc usr/local/bin/nwnsc
COPY --from=nwnsc /nwn /nwn
RUN dpkg --add-architecture i386 \
    && apt update \
    && apt upgrade -y \
    && apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386 -y \
    && choosenim update stable \
    && nimble install nasher@#0.11.9 -y \
    && nasher config --nssFlags:"-n /nwn/data -o" \
    && nasher config --installDir:"/nasher/install"
RUN nasher config --userName:"nasher"
ENV PATH="/root/.nimble/bin:${PATH}"
WORKDIR /nasher
RUN bash -c 'mkdir -pv /nasher/install/{modules,erf,hak,tlk}'
ENTRYPOINT [ "nasher" ]
CMD [ "list --quiet" ]
