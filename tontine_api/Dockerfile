# Image de développement pour l'API Laravel (Tontine Digitale)
# Configuration par défaut : SQLite + queue/cache/session en base (cf .env.example)
FROM php:8.3-cli

# Dépendances système + extensions PHP requises par Laravel 12 / Passport
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libzip-dev \
        libsqlite3-dev \
        libonig-dev \
    && docker-php-ext-install -j"$(nproc)" pdo_sqlite bcmath zip mbstring \
    && rm -rf /var/lib/apt/lists/*

# Composer (copié depuis l'image officielle)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Entrypoint placé hors de /app pour ne pas être masqué par le volume monté
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["docker-entrypoint.sh"]
