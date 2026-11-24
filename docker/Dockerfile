# Stage 1: Composer dependencies
FROM composer:2 AS vendor
WORKDIR /app
COPY app/composer.json ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

# Stage 2: PHP-FPM + Nginx Alpine runtime (<300 MB)
FROM php:8.3-fpm-alpine

RUN apk add --no-cache nginx supervisor \
    && docker-php-ext-install pdo_mysql opcache \
    && rm -rf /var/cache/apk/*

RUN addgroup -g 10001 appgroup && adduser -u 10001 -G appgroup -s /bin/sh -D appuser \
    && mkdir -p /var/www/html /var/log/nginx /var/log/supervisor /var/lib/nginx/tmp /run/nginx \
    && chown -R appuser:appgroup /var/www/html /var/log/nginx /var/log/supervisor /var/lib/nginx /run/nginx

WORKDIR /var/www/html
COPY --chown=appuser:appgroup app/ ./
COPY --from=vendor --chown=appuser:appgroup /app/vendor ./vendor
COPY --chown=appuser:appgroup nginx/default.conf /etc/nginx/http.d/default.conf

RUN printf '[supervisord]\nnodaemon=true\npidfile=/tmp/supervisord.pid\n\n[program:php-fpm]\ncommand=php-fpm -F\n\n[program:nginx]\ncommand=nginx -g "daemon off;"\n' > /etc/supervisord.conf \
    && sed -i 's/user nginx;/# user nginx;/g' /etc/nginx/nginx.conf \
    && sed -i 's|/run/nginx/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf

ENV APP_NAME="iCloudEMS-ERP" APP_ENV="production"
EXPOSE 8080
USER appuser

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
