# The upstream image (samwierema/go-qr-generator, 2015) uses a manifest format
# that modern Docker can no longer pull, so we build the same tiny service from
# source. Same API: GET /?data=<text>&size=<px>
FROM golang:1.25-alpine AS build
ARG QR_COMMIT=e114f2c69c584ed214c7b66c437ab257c9b0af79
WORKDIR /src
ADD https://raw.githubusercontent.com/samwierema/go-qr-generator/${QR_COMMIT}/main.go main.go
RUN go mod init qr && go mod tidy && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /qr .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /qr /qr
EXPOSE 8080
ENTRYPOINT ["/qr"]
