FROM buildpack-deps:stretch

LABEL maintainer="eelcohn"

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.17.9
ENV NGINX_RTMP_MODULE_VERSION 1.2.1
ENV ICECAST_VERSION 2.4.4
ENV STUNNEL_VERSION 5.56

# Install dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates openssl libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Download and decompress Icecast
RUN mkdir -p /tmp/build/icecast && \
    cd /tmp/build/icecast && \
    wget -O ${ICECAST_VERSION}.tar.gz "http://downloads.xiph.org/releases/icecast/icecast-$ICECAST_VERSION.tar.gz" && \
    tar -zxf ${ICECAST_VERSION}.tar.gz

# Download and decompress Icecast
RUN mkdir -p /tmp/build/stunnel && \
    cd /tmp/build/stunnel && \
    wget -O ${STUNNEL_VERSION}.tar.gz "https://www.stunnel.org/downloads/stunnel-$STUNNEL_VERSION.tar.gz" && \
    tar -zxf ${STUNNEL_VERSION}.tar.gz

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --with-ipv6 \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx &&

# Download, compile and install Icecast
RUN cd /tmp/build/icecast/icecast-${ICECAST_VERSION} && \
  && ./configure \
  && make \
  && make install \
  && cd .. \
  && rm -r "icecast-$ICECAST_VERSION"

# Download, compile and install STunnel
RUN cd /tmp/build/stunnel/stunnel-${STUNNEL_VERSION} && \
  && ./configure \
  && make \
  && make install \
  && cd .. \
  && rm -r "icecast-$STUNNEL_VERSION"

# Remove build files
RUN  rm -rf /tmp/build

# Configure Icecast user
RUN adduser --disabled-password '' icecast2

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Set up config file
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 1935
CMD ["nginx", "-g", "daemon off;"]
