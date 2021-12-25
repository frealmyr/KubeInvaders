FROM nginx

# Install kubectl
RUN curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# Install Openresty
RUN apt-get update
RUN apt-get -y install wget gnupg
RUN wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
RUN codename=`grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release` && echo "deb http://openresty.org/package/debian $codename openresty" | tee /etc/apt/sources.list.d/openresty.list
RUN apt-get update
RUN apt-get -y install openresty luarocks libssl-dev git vim lua-json lua-socket procps wget gnupg ca-certificates jq openssl task-spooler at python3 python3-pip
RUN apt-get autoclean
RUN apt-get update --fix-missing
RUN chmod 777 /usr/local/openresty/nginx
RUN luarocks install luasec 
RUN luarocks install lunajson

# Install WebSocket Server
COPY websocket /opt/websocket
RUN pip3 install -r /opt/websocket/requirements.txt

# Install kube-linter
RUN curl -L -O https://github.com/stackrox/kube-linter/releases/download/0.2.4/kube-linter-linux.tar.gz
RUN tar -xvf kube-linter-linux.tar.gz
RUN rm -f kube-linter-linux.tar.gz
RUN cp  kube-linter /usr/local/bin/
RUN chmod 775 /usr/local/bin/kube-linter
RUN mkdir /tmp/kube-linter-pods
RUN chmod 777 /tmp/kube-linter-pods

COPY kube-linter/kube-linter-parser.sh /opt/kube-linter-parser.sh
RUN chmod +x /opt/kube-linter-parser.sh

# Install secpod_wrap
COPY secpod_wrap /opt/secpod_wrap
RUN pip3 install -r /opt/secpod_wrap/requirements.txt
RUN chmod -R 777 /opt/secpod_wrap

# Install Trivy
RUN wget https://github.com/aquasecurity/trivy/releases/download/v0.19.2/trivy_0.19.2_Linux-64bit.deb
RUN dpkg -i trivy_0.19.2_Linux-64bit.deb && rm -f trivy_0.19.2_Linux-64bit.deb

# Install game part
COPY html5/ /var/www/html

# Install Redis
RUN apt-get install redis -y
COPY redis/redis.conf /etc/redis/redis.conf

# Configure Nginx
RUN sed -i.bak 's/listen\(.*\)80;/listen 8081;/' /etc/nginx/conf.d/default.conf
RUN mkdir /usr/local/openresty/nginx/conf/kubeinvaders

COPY nginx/nginx.conf /etc/nginx/nginx.conf

COPY scripts/metrics.lua /usr/local/openresty/nginx/conf/kubeinvaders/metrics.lua
COPY scripts/pod.lua /usr/local/openresty/nginx/conf/kubeinvaders/pod.lua
COPY scripts/node.lua /usr/local/openresty/nginx/conf/kubeinvaders/node.lua
COPY scripts/kube-linter.lua /usr/local/openresty/nginx/conf/kubeinvaders/kube-linter.lua
COPY scripts/chaos-node.lua /usr/local/openresty/nginx/conf/kubeinvaders/chaos-node.lua
COPY scripts/chaos-containers.lua /usr/local/openresty/nginx/conf/kubeinvaders/chaos-containers.lua
COPY scripts/config_kubeinv.lua /usr/local/openresty/lualib/config_kubeinv.lua
COPY scripts/secpod_wrap.lua /usr/local/openresty/nginx/conf/kubeinvaders/secpod_wrap.lua
COPY scripts/params.lua /usr/local/openresty/nginx/conf/kubeinvaders/params.lua
COPY nginx/KubeInvaders.conf /etc/nginx/conf.d/KubeInvaders.conf

RUN chmod g+rwx /var/cache/nginx /var/run /var/log/nginx /var/www/html /etc/nginx/conf.d
RUN apt-get clean

EXPOSE 8080

ENV PATH=/usr/local/openresty/nginx/sbin:$PATH
COPY ./entrypoint.sh /
RUN chmod a+rwx ./entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
