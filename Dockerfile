FROM alpine:3.7

RUN set -xe \
    && echo "@php http://dl-cdn.alpinelinux.org/alpine/v3.7/community" >> /etc/apk/repositories \
    && apk --update add --no-cache \
        openssh \
        openssl \
        bash \
        mc \
        nginx \
        supervisor \
        curl \
        zip unzip \
        git \
        dcron

RUN set -xe \
    && apk --no-cache add \
        php7 \
        php7-fpm \
        php7-ctype \
        php7-curl \
        php7-dom \
        php7-fileinfo \
        php7-iconv \
        php7-json \
        php7-mbstring \
        php7-pear \
        php7-phar \
        php7-posix \
        php7-xml \
        php7-xmlreader \
        php7-xmlwriter \
        php7-zlib \
        php7-gd \
        php7-mcrypt \
        php7-zip \
        php7-intl \
        php7-redis \
        php7-pear \
        php7-pcntl \
        php7-exif \
        php7-ldap \
        php7-bcmath \
        php7-soap \
        php7-zmq \
        php7-sockets \
        php7-amqp \
        php7-opcache \
        php7-gettext \
        php7-imap \
        php7-xdebug \
        php7-bz2 \
        php7-tidy \
        # Database Drivers
        php7-pdo_mysql \
        php7-mysqlnd \
        php7-pdo_pgsql \
        php7-pgsql \
        # CUSTOM
        php7-apcu

# install and remove building packages
ENV PHPIZE_DEPS autoconf file g++ gcc libc-dev make pkgconf re2c php7-dev php7-pear

ENV PHP_INI_DIR /etc/php7

RUN set -xe \
    && apk add --no-cache --repository "http://dl-cdn.alpinelinux.org/alpine/edge/testing" \
    --virtual .phpize-deps \
    $PHPIZE_DEPS \
    && apk add --no-cache libevent-dev openssl-dev libsodium-dev \
    && sed -i 's/^exec $PHP -C -n/exec $PHP -C/g' $(which pecl) \
    && pecl channel-update pecl.php.net \
    && pecl install event libsodium \
    && echo "extension=event.so" > $PHP_INI_DIR/conf.d/01_event.ini \
    && echo "extension=sodium.so" > $PHP_INI_DIR/conf.d/01_sodium.ini \
    && rm -rf /usr/share/php7 \
    && rm -rf /tmp/* \
    && apk del .phpize-deps \
    && rm -rf /var/cache/apk/*

# Configue SSH
COPY ./.build/docker/sshd_config /etc/ssh/
ENV SSH_PASSWD "root:Docker!"
RUN echo "$SSH_PASSWD" | chpasswd

RUN sed -ri 's/#HostKey \/etc\/ssh\/ssh_host_key/HostKey \/etc\/ssh\/ssh_host_key/g' /etc/ssh/sshd_config \
&& sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/g' /etc/ssh/sshd_config \
&& sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_dsa_key/HostKey \/etc\/ssh\/ssh_host_dsa_key/g' /etc/ssh/sshd_config \
&& sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ecdsa_key/HostKey \/etc\/ssh\/ssh_host_ecdsa_key/g' /etc/ssh/sshd_config \
&& sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/g' /etc/ssh/sshd_config \
&& /usr/bin/ssh-keygen -A \
&& ssh-keygen -t rsa -b 4096 -f  /etc/ssh/ssh_host_key

# Composer
RUN set -xe \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

RUN mkdir /home/composer && chown nobody:nogroup -R /home/composer

ENV COMPOSER_HOME=/home/composer

RUN composer global require hirak/prestissimo

COPY ./.build/docker/index.php /var/www

# Configure PHP
COPY ./.build/docker/www.conf /etc/php7/php-fpm.d/www.conf
RUN sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php7/php.ini \
	&& sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php7/php.ini \
	&& sed -i "s/short_open_tag =.*/short_open_tag = Off/" /etc/php7/php.ini \
	&& sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php7/php-fpm.conf \
	&& sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php7/php.ini \
	&& sed -i "s/session.auto_start\s*=.*/session.auto_start = 0/" /etc/php7/php.ini

#NGinx
COPY ./.build/docker/nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /etc/nginx/sites-enabled
ADD ./.build/docker/default.conf /etc/nginx/sites-enabled/default.conf

#Supervisor configs
RUN rm -rf /etc/supervisor.d/*.ini
COPY ./.build/docker/supervisord/*.conf /etc/supervisor.d/
RUN sed -i "s/files\s*=.*/files = \/etc\/supervisor.d\/\*.conf/" /etc/supervisord.conf

# Copy initialize script
COPY ./.build/docker/init_container.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init_container.sh

EXPOSE 2222 8000

# Define entrypoint
ENTRYPOINT ["init_container.sh"]
