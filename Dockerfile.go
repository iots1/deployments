FROM --platform="linux/amd64" golang:1.23.4-bullseye AS build

WORKDIR /app

COPY . ./
RUN go mod download

RUN CGO_ENABLED=0 go build -o /bin/app

FROM --platform="linux/amd64" debian:bullseye-slim

COPY --from=build /bin/app /bin

ENV ENV_MODE=production

RUN apt update
RUN apt install -y ca-certificates

EXPOSE 8787

CMD ["/bin/app"]
