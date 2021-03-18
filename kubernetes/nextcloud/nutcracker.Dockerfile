FROM alpine:latest
COPY nutcracker.conf /etc
RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add git automake libtool curl wget autoconf g++ make --virtual .deps1  && \
    wget https://github.com/twitter/twemproxy/archive/v0.4.1.tar.gz -O - | tar -xz && \
    cd twemproxy-0.4.1 && \
    autoreconf -fvi && \
    ./configure && \
    make && \
    cp src/nutcracker  /usr/local/bin/ && \
    apk del .deps1  && \
    cd .. && \
    rm -rf twemproxy-0.4.1
CMD /usr/local/bin/nutcracker -c /etc/nutcracker.conf --verbose=11


