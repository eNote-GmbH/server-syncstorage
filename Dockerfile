FROM python:2.7-alpine

WORKDIR /app

RUN addgroup -g 10001 app && \
    adduser -D -u 10001 -G app -h /app -s /sbin/nologin app


# run the server by default
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["server"]

# install / cache dependencies first
COPY requirements.txt /app/requirements.txt

# install dependencies, cleanup and add libstdc++ back in since
# we the app needs to link to it
RUN apk add --update build-base ca-certificates && \
    pip install -r requirements.txt && \
    apk del --purge build-base gcc && \
    apk add libstdc++


# Copy in the whole app after dependencies have been installed & cached
COPY . /app
RUN python setup.py develop && \
    find /app -type d -exec chmod 755 {} \; && \
    find /app -type f -exec chmod 644 {} \; && \
    chmod 755 /app/docker-entrypoint.sh

# De-escalate from root privileges with app user
USER app
