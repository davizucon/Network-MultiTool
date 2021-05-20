FROM alpine:3.12
#FROM alpine
MAINTAINER Kamran Azeem & Henrik Høegh (kaz@praqma.net, heh@praqma.net)

# Install some tools in the container.
# Packages are listed in alphabetical order, for ease of readability and ease of maintenance.
RUN     apk update \
    &&  apk add apache2-utils bash bind-tools busybox-extras curl ethtool git iperf\
                iperf3 iproute2 iputils jq lftp mtr mysql-client \
                netcat-openbsd net-tools nginx nmap openssh-client openssl \
	        perl-net-telnet postgresql-client procps rsync socat tcpdump tshark wget kafkacat stunnel\
    &&  mkdir /certs \
    &&  chmod 700 /certs


RUN apk add --no-cache gcc make alpine-sdk openssl-dev libressl-dev build-base #linux-headers lksctp-tools-dev lksctp-tools

RUN curl -LO https://github.com/redis/redis/archive/refs/tags/6.2.3.zip && unzip 6.2.3.zip 
RUN cd redis-6.2.3/deps && make BUILD_TLS=yes hiredis lua jemalloc linenoise
RUN cd redis-6.2.3 && make BUILD_TLS=yes redis-cli
RUN rm -Rf redis-6.2.3/ 6.2.3.zip


## netperf
RUN	curl -LO https://github.com/HewlettPackard/netperf/archive/netperf-2.7.0.tar.gz && \
	tar -xzf netperf-2.7.0.tar.gz 
RUN	cd netperf-netperf-2.7.0 && ./configure --prefix=/usr --enable-histogram \
        --enable-unixdomain \
        --enable-dccp \
        --enable-omni \
        --enable-exs \
        --enable-sctp \
        --enable-intervals \
        --enable-spin \
        --enable-burst \
        --enable-cpuutil=procstat

RUN cd netperf-netperf-2.7.0 && make 
RUN cd netperf-netperf-2.7.0 && make install
RUN	rm -rf netperf-2.7.0 netperf-2.7.0.tar.gz && \
	rm -f /usr/share/info/netperf.info && \
	strip -s /usr/bin/netperf /usr/bin/netserver && \
	apk del build-base && rm -rf /var/cache/apk/*




# Interesting:
# Users of this image may wonder, why this multitool runs a web server? 
# Well, normally, if a container does not run a daemon, 
#   ,then running it involves using creative ways / hacks to keep it alive.
# If you don't want to suddenly start browsing the internet for "those creative ways",
#  ,then it is best to run a web server in the container - as the default process.
# This helps when you are on kubernetes platform and simply execute:
#   $ kubectl run multitool --image=praqma/network-multitool --replicas=1
# Or, on Docker:
#   $ docker run  -d praqma/network-multitool

# The multitool container starts as web server. Then, you simply connect to it using:
#   $ kubectl exec -it multitool-3822887632-pwlr1  bash
# Or, on Docker:
#   $ docker exec -it silly-container-name bash 

# This is why it is good to have a webserver in this tool. Hope this answers the question!
#
# Besides, I believe that having a web server in a multitool is like having yet another tool! 
# Personally, I think this is cool! Henrik thinks the same!

# Copy a simple index.html to eliminate text (index.html) noise which comes with default nginx image.
# (I created an issue for this purpose here: https://github.com/nginxinc/docker-nginx/issues/234)
COPY index.html /usr/share/nginx/html/


# Copy a custom nginx.conf with log files redirected to stderr and stdout
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx-connectors.conf /etc/nginx/conf.d/default.conf
COPY server.* /certs/

EXPOSE 80 443

COPY docker-entrypoint.sh /


# Run the startup script as ENTRYPOINT, which does few things and then starts nginx.
ENTRYPOINT ["/docker-entrypoint.sh"]


# Start nginx in foreground:
CMD ["nginx", "-g", "daemon off;"]


###################################################################################################

# Build and Push (to dockerhub) instructions:
# -------------------------------------------
# docker build -t local/network-multitool .
# docker tag local/network-multitool praqma/network-multitool
# docker login
# docker push praqma/network-multitool


# Pull (from dockerhub):
# ----------------------
# docker pull praqma/network-multitool


# Usage - on Docker:
# ------------------
# docker run --rm -it praqma/network-multitool /bin/bash 
# OR
# docker run -d  praqma/network-multitool
# OR
# docker run -p 80:80 -p 443:443 -d  praqma/network-multitool
# OR
# docker run -e HTTP_PORT=1080 -e HTTPS_PORT=1443 -p 1080:1080 -p 1443:1443 -d  praqma/network-multitool


# Usage - on Kubernetes:
# ---------------------
# kubectl run multitool --image=praqma/network-multitool --replicas=1
