#!/bin/sh
# Démarrage idempotent de l'API : dépendances, clés, migrations, Passport, serveur.
set -e
cd /app

echo "→ [1/6] composer install"
composer install --no-interaction --prefer-dist --no-progress

if [ ! -f .env ]; then
    echo "→ création du .env depuis .env.example"
    cp .env.example .env
fi

echo "→ [2/6] base SQLite"
mkdir -p database
touch database/database.sqlite

echo "→ [3/6] APP_KEY"
php artisan key:generate --force

echo "→ [4/6] migrations"
php artisan migrate --force

# Clés de chiffrement Passport + client d'accès personnel (une seule fois)
if [ ! -f storage/oauth-private.key ]; then
    echo "→ [5/6] Passport : clés + client personnel"
    php artisan passport:keys --force
    php artisan passport:client --personal --no-interaction --name="Tontine Personal Access Client"
else
    echo "→ [5/6] Passport déjà configuré"
fi

php artisan config:clear

echo "→ [6/6] API disponible sur http://localhost:8000"
exec php artisan serve --host=0.0.0.0 --port=8000
