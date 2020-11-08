ARG nasher_version=0.13.0
ARG nim_version=1.4.0
# nwnsc compiler
FROM nwneetools/nwnsc:latest as nwnsc
# nim image
FROM nimlang/nim:${nim_version}-alpine
COPY --from=nwnsc usr/local/bin/nwnsc usr/local/bin/nwnsc
COPY --from=nwnsc /nwn /nwn
RUN nimble install nasher@#${nasher_version} -y \
    && nasher config --nssFlags:"-n /nwn/data -o" \
    && nasher config --installDir:"/nasher/install" \
    && nasher config --userName:"nasher"
WORKDIR /nasher
RUN bash -c 'mkdir -pv /nasher/install/{modules,erf,hak,tlk}'
ENTRYPOINT [ "nasher" ]
CMD [ "list --quiet" ]
