FROM golang:1.13-alpine as builder

RUN apk add --no-cache git gcc libc-dev

ENV GOOS=linux
ENV GOARCH=amd64
ENV CGO_ENABLED=0

COPY $PWD/ /src/app/
WORKDIR /src/app/

RUN go build -a -tags netgo -ldflags '-w -extldflags "-static"' -o /go/bin/testApi

# Originally here was FROM scratch, but Cloud CQL proxy requires some minimal OS environment and ca-certificates.
FROM alpine:latest

RUN apk add --no-cache ca-certificates

COPY --from=builder /go/bin/testApi /app/testApi

WORKDIR /app

CMD ["/app/testApi"]
