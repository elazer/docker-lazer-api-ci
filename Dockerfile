FROM php:7.4-fpm-alpine

# persistent / runtime deps
RUN apk add --no-cache \
		acl \
		ca-certificates \
		curl \
		fcgi \
		file \
		gettext \
		git \
		gmp \
		icu-libs \
        libssl1.1 \
		zlib

ARG APCU_VERSION=5.1.18
RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		gmp-dev \
		icu-dev \
		libzip-dev \
		zlib-dev \
		libxml2-dev \
	; \
	\
	docker-php-ext-configure zip; \
	docker-php-ext-install -j$(nproc) \
		bcmath \
		gmp \
		intl \
		zip \
		soap \
	; \
	pecl install \
		apcu-${APCU_VERSION} \
		ds \
		mongodb \
	; \
	pecl clear-cache; \
	docker-php-ext-enable \
		apcu \
		ds \
		mongodb \
		opcache \
	; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache --virtual .api-phpexts-rundeps $runDeps; \
	\
	apk del .build-deps

COPY install-composer.sh /usr/local/bin/docker-app-install-composer
RUN chmod +x /usr/local/bin/docker-app-install-composer

RUN set -xe \
	&& apk add --no-cache --virtual .fetch-deps \
		openssl \
	&& docker-app-install-composer \
	&& mv composer.phar /usr/local/bin/composer \
	&& apk del .fetch-deps

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER 1

ENV COMPOSER_HOME /root/.composer
ENV PATH $PATH:$COMPOSER_HOME/vendor/bin

COPY composer.json /root/.composer
COPY php.ini /usr/local/etc/php/

RUN composer global update --prefer-dist --no-progress --no-suggest --optimize-autoloader --classmap-authoritative \
	&& composer clear-cache
