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
    && nimble install nasher@#0.11.8 -y \
    && nasher config --nssFlags:"-n /nwn/data -o"
RUN nasher config --userName:"nasher"
ENV PATH="/root/.nimble/bin:${PATH}"
WORKDIR /nasher
ENTRYPOINT [ "nasher" ]
CMD [ "list --quiet" ]
