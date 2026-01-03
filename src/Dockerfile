FROM langfuse/langfuse:2

USER root

# Install PostgreSQL and necessary dependencies
RUN apk update && apk add --no-cache \
    postgresql \
    postgresql-contrib \
    net-tools \
    iproute2 \
    sed


RUN mkdir -p /data && chmod -R 777 /data


# Copy and set up the wrapper script
COPY docker-entrypoint-wrapper.sh /docker-entrypoint-wrapper.sh
RUN chmod +x /docker-entrypoint-wrapper.sh

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--", "/docker-entrypoint-wrapper.sh"]