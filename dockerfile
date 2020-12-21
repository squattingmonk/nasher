# nwnsc compiler
FROM nwneetools/nwnsc:latest as nwnsc
# nim image
FROM nimlang/nim:alpine as nasher
COPY --from=nwnsc usr/local/bin/nwnsc usr/local/bin/nwnsc
COPY --from=nwnsc /nwn /nwn
RUN apk add --no-cache bash pcre
ARG NASHER_VERSION="0.14.0"
ENV PATH="/root/.nimble/bin:$PATH"
RUN nimble install nasher@#${NASHER_VERSION} -y
RUN nasher config --nssFlags:"-n /nwn/data -o" \
    && nasher config --installDir:"/nasher/install" \
    && nasher config --userName:"nasher"
WORKDIR /nasher
RUN bash -c "mkdir -pv /nasher/install/{erf,hak,modules,tlk}"
ENTRYPOINT [ "nasher" ]
CMD [ "--help" ]
