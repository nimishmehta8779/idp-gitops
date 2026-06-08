{% if values.language == 'nodejs' %}
FROM node:20-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 3000
CMD [ "node", "index.js" ]
{% elif values.language == 'python' %}
FROM python:3.11-slim
WORKDIR /usr/src/app
COPY requirements.txt* ./
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi
COPY . .
EXPOSE 8000
CMD [ "python", "app.py" ]
{% elif values.language == 'golang' %}
FROM golang:1.21-alpine AS builder
WORKDIR /src
COPY go.mod* go.sum* ./
RUN if [ -f go.mod ]; then go mod download; fi
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/service .

FROM alpine:3.18
COPY --from=builder /bin/service /bin/service
EXPOSE 8080
ENTRYPOINT [ "/bin/service" ]
{% endif %}
