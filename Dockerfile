# STAGE 1: Build PolkADAPT submodule and Explorer UI application

FROM node:lts AS builder

WORKDIR /app/polkadapt

COPY polkadapt/package.json .
RUN npm i

COPY polkadapt/projects/core/package.json projects/core/package.json
RUN cd projects/core && npm i

COPY polkadapt/angular.json polkadapt/tsconfig.json ./
COPY polkadapt/projects/core projects/core
RUN npm exec ng build -- --configuration production core

COPY polkadapt/projects/substrate-rpc/package.json projects/substrate-rpc/package.json
RUN cd projects/substrate-rpc && npm i

COPY polkadapt/projects/polkascan-explorer/package.json projects/polkascan-explorer/package.json
RUN cd projects/polkascan-explorer && npm i

COPY polkadapt/projects/coingecko/package.json projects/coingecko/package.json
RUN cd projects/coingecko && npm i

COPY polkadapt/projects/subsquid/package.json projects/subsquid/package.json
RUN cd projects/subsquid && npm i

COPY polkadapt .
RUN npm exec ng build -- --configuration production substrate-rpc
RUN npm exec ng build -- --configuration production polkascan-explorer
RUN npm exec ng build -- --configuration production coingecko
RUN npm exec ng build -- --configuration production subsquid

# Main App
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY angular.json tsconfig.json tsconfig.app.json tsconfig.worker.json ./
COPY src/ src/

RUN rm -rf node_modules/@polkadapt && mkdir -p node_modules/@polkadapt \
    && cp -r /app/polkadapt/dist/core node_modules/@polkadapt/ \
    && cp -r /app/polkadapt/dist/substrate-rpc node_modules/@polkadapt/ \
    && cp -r /app/polkadapt/dist/polkascan-explorer node_modules/@polkadapt/ \
    && cp -r /app/polkadapt/dist/coingecko node_modules/@polkadapt/ \
    && cp -r /app/polkadapt/dist/subsquid node_modules/@polkadapt/

ARG ENV_CONFIG=production
ENV ENV_CONFIG=$ENV_CONFIG
RUN npm exec ng build -- --configuration ${ENV_CONFIG}

# STAGE 2: Nginx runtime

FROM nginx:stable-alpine
LABEL description="Container image for THXNET." \
    io.thxnet.image.type="final" \
    io.thxnet.image.authors="contact@thxlab.io" \
    io.thxnet.image.vendor="thxlab.io" \
    io.thxnet.image.description="THXNET.: Blockchain Explorer Frontend" \
    org.opencontainers.image.source="https://github.com/thxnet/blockchain-explorer-ui"

ARG NGINX_CONF=nginx/explorer-ui.conf
ENV NGINX_CONF=$NGINX_CONF

RUN rm -rf /etc/nginx/conf.d/*
COPY ${NGINX_CONF} /etc/nginx/conf.d/

RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /app/dist/explorer-ui /usr/share/nginx/html

EXPOSE 80
CMD ["/bin/sh", "-c", "exec nginx -g 'daemon off;'"]
