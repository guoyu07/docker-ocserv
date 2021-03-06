#
# Dockerfile for ocserv
# 

FROM alpine:3.7

ENV OC_VERSION=0.11.10

RUN buildDeps=" \
		g++ \
		gnutls-dev \
		gpgme \
		libev-dev \
		libnl3-dev \
		libseccomp-dev \
		linux-headers \
		linux-pam-dev \
		lz4-dev \
		make \
		readline-dev \
		tar \
		xz \
	"; \
	set -x \
	&& apk add --update --virtual .build-deps $buildDeps \
	&& apk add curl gnutls-utils iptables \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz.sig" -o ocserv.tar.xz.sig \
	&& gpg --keyserver pgp.key-server.io --recv-key 7F343FA7 \
	&& gpg --keyserver pgp.key-server.io --recv-key 96865171 \
	&& gpg --verify ocserv.tar.xz.sig \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure \
	&& make \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cp /usr/src/ocserv/doc/sample.config /etc/ocserv/ocserv.conf \
	&& cd / \
	&& rm -rf /usr/src/ocserv \
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/local/sbin/ocserv \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| xargs -r apk info --installed \
			| sort -u \
		)" \
	&& apk add --virtual .run-deps $runDeps \
	&& apk del .build-deps \
	&& apk add libnl3 readline \
	&& rm -rf /var/cache/apk

# Setup config
COPY groupinfo.txt /tmp/
RUN set -x \
	&& sed -i 's/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/\(max-same-clients = \)2/\110/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/\.\.\/tests/\/etc\/ocserv/' /etc/ocserv/ocserv.conf \
	&& sed -i '/^try-mtu-discovery = /{s/false/true/}' /etc/ocserv/ocserv.conf \
	&& sed -i 's/#\(compression.*\)/\1/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/#\(no-compress-limit.*\)/\1/' /etc/ocserv/ocserv.conf \
	&& sed -i '/^tcp-port = /{s/443/PORT/}' /etc/ocserv/ocserv.conf \
	&& sed -i '/^udp-port = /{s/443/PORT/}' /etc/ocserv/ocserv.conf \
	&& sed -i '/^ipv4-network = /{s/192.168.1.0/IPV4/}' /etc/ocserv/ocserv.conf \
	&& sed -i '/^ipv4-netmask = /{s/255.255.255.0/IPV4MASK/}' /etc/ocserv/ocserv.conf \
	&& sed -i '/^dns = /{s/192.168.1.2/DNS/}' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^route/#route/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^no-route/#no-route/' /etc/ocserv/ocserv.conf \
	&& mkdir -p /etc/ocserv/config-per-group \
	&& cat /tmp/groupinfo.txt >> /etc/ocserv/ocserv.conf \
	&& rm -rf /tmp/groupinfo.txt

WORKDIR /etc/ocserv

COPY All /etc/ocserv/config-per-group/All
COPY docker-entrypoint.sh /entrypoint.sh

ENV PORT     443
ENV IPV4     10.10.10.0
ENV IPV4MASK 255.255.255.0
ENV DNS      8.8.8.8
ENV DNS2     8.8.4.4

EXPOSE $PORT/tcp
EXPOSE $PORT/udp

ENTRYPOINT ["/entrypoint.sh"]
