FROM alpine:latest

RUN apk add --no-cache openssh bash && \
    ssh-keygen -A && \
    mkdir -p /var/run/sshd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
CMD ["/entrypoint.sh"]
