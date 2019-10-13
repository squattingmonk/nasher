# nwnsc compiler
FROM jakkn/nwnsc as nwnsc
# nim image
FROM nimlang/nim:latest as nashor
COPY --from=nwnsc usr/local/bin/nwnsc usr/local/bin/nwnsc
COPY --from=nwnsc /nwn /nwn
RUN apt update \
    && apt upgrade -y \
    && nimble install nasher -y
ENV PATH="/root/.nimble/bin:${PATH}"
WORKDIR /nwn-build
ENTRYPOINT [ "nasher" ]
CMD [ "stats" ]