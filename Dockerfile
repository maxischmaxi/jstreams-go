FROM golang:1.23.2 as golang

ARG GH_TOKEN
ARG GH_SHA

ENV GH_TOKEN=$GH_TOKEN
ENV GITHUB_SHA=$GH_SHA

RUN git config --global user.email "max@jeschek.dev" && \
    git config --global user.name "maxischmaxi"

RUN go install github.com/bufbuild/buf/cmd/buf@latest && \
    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest && \
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install connectrpc.com/connect/cmd/protoc-gen-connect-go@latest

RUN [ -n "$(go env GOBIN)" ] && export PATH="$(go env GOBIN):${PATH}" && \
    [ -n "$(go env GOPATH)" ] && export PATH="$(go env GOPATH)/bin:${PATH}"

WORKDIR /app

COPY . .

RUN buf generate --template buf.gen.go.yaml

RUN git clone https://github.com/maxischmaxi/jstreams-go.git && \
    cd jstreams-go && \
    find . -mindepth 1 ! -name "go.mod" -exec rm -rf {} + && \
    cp -r ../gen-go/* . && \
    git add . && \
    git commit -m "$GITHUB_SHA" && \
    git remote set-url origin https://maxischmaxi:${GH_TOKEN}@github.com/maxischmaxi/jstreams-go.git && \
    git push -u origin main && \
    git tag -a "$GITHUB_SHA" -m "$GITHUB_SHA" && \
    git push origin "$GITHUB_SHA"

FROM node:latest as nodejs

WORKDIR /app
RUN git clone https://github.com/maxischmaxi/jstreams-ts.git && \
    cd jstreams-ts && \
    find . -type f \( -name "*.js" -o -name "*.d.ts" \) -not -path "./node_modules/*" -exec rm -v {} \; && \
    npm ci && \
    npx buf generate --template ../buf.gen.ts.yaml && \
    git add . && \
    git commit -m "$GITHUB_SHA" && \
    git remote set-url origin https://maxischmaxi:${GH_TOKEN}@github.com/maxischmaxi/jstreams-ts.git && \
    git push -u origin main && \
    npm publish
