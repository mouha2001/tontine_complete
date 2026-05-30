# 🏦 Tontine Digitale — Guide d'installation complet

## Architecture globale

```
Flutter App (Mobile/Web)
       ↕ HTTPS + Bearer Token
Laravel 11 API (Backend)
       ↕ MySQL + Redis
Base de données + Cache
       ↕ Webhooks
Wave / Orange Money (Paiements)
       ↕ FCM
Firebase (Notifications Push)
```

---

## 📦 1. INSTALLATION LARAVEL (Backend)

### Prérequis
- PHP 8.2+
- MySQL 8.0+
- Redis 7+
- Composer 2+

### Installation

```bash
# Cloner et installer
git clone <repo>
cd laravel/
composer install

# Configuration
cp .env.example .env
php artisan key:generate

# Base de données
mysql -u root -p -e "CREATE DATABASE tontine_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Migrations + seeders
php artisan migrate
php artisan db:seed

# Passport (OAuth2)
php artisan passport:install
# → Copier les Client ID/Secret générés si nécessaire

# Démarrer (développement)
php artisan serve
```

### Commandes utiles

```bash
# Vider les caches
php artisan optimize:clear

# Lancer les jobs en queue (paiements, notifications)
php artisan queue:work --queue=default,notifications

# Générer clé Passport
php artisan passport:keys
```

---

## 📱 2. INSTALLATION FLUTTER (Mobile)

### Prérequis
- Flutter SDK 3.10+
- Android Studio / Xcode
- Compte Firebase (pour les notifications)

### Installation

```bash
cd flutter/
flutter pub get

# Configurer l'URL de l'API
# Modifier lib/services/api_service.dart ligne 7 :
# static const String baseUrl = 'https://votre-api.com/api';
```

### Configuration Firebase

```bash
# 1. Créer un projet sur https://console.firebase.google.com
# 2. Activer Cloud Messaging
# 3. Télécharger google-services.json → placer dans android/app/
# 4. Télécharger GoogleService-Info.plist → placer dans ios/Runner/
```

### Lancer l'app

```bash
# Android
flutter run --release

# iOS
flutter run --release --target=lib/main.dart

# Web
flutter run -d chrome
```

---

## 🔑 3. CONFIGURATION DES RÔLES

### Roles disponibles
| Rôle | Valeur DB | Accès |
|------|-----------|-------|
| Administrateur | `admin` | Création tontines, invitations, tirage, supervision Sutura |
| Membre | `membre` | Cotisations, votes Sutura, historique |

### Comment les rôles sont appliqués

**Laravel :** Le rôle est stocké dans `users.role`. Chaque controller vérifie :
```php
$request->user()->isAdmin  // true/false
$request->user()->role     // 'admin' ou 'membre'
```

**Flutter :** Le rôle est stocké dans `UserModel.role` (enum) et dans `AuthProvider._user`.
La navigation dans `HomeScreen` adapte automatiquement le menu selon le rôle.

---

## 💳 4. INTÉGRATION PAIEMENTS

### Wave
```env
WAVE_API_KEY=sk_live_xxxxxxxx
WAVE_WEBHOOK_SECRET=whsec_xxxxxxxx
```
- Dashboard : https://developer.wave.com
- Webhook URL à configurer : `https://votre-api.com/api/cotisations/webhook`

### Orange Money
```env
ORANGE_MONEY_CLIENT_ID=xxxx
ORANGE_MONEY_CLIENT_SECRET=xxxx
ORANGE_MONEY_MERCHANT_KEY=xxxx
```
- Dashboard : https://developer.orange.com/apis/om-webpay-sn

---

## 🗃️ 5. SCHÉMA BASE DE DONNÉES

```
users
├── id, nom, telephone (unique), email, adresse
├── role: ENUM('admin', 'membre')
├── otp_code, otp_expires_at
├── telephone_verified, fcm_token
└── timestamps, soft_deletes

tontines
├── id, admin_id (FK users), nom, description
├── montant_cotisation, frequence, nombre_membres
├── statut: ENUM('en_attente', 'active', 'terminee')
├── date_debut, date_fin, tour_actuel
├── invite_code (unique)
└── timestamps, soft_deletes

tontine_membres (pivot)
├── tontine_id (FK), user_id (FK)
├── ordre_tirage, a_recu_fonds
└── unique(tontine_id, user_id)

cotisations
├── id, tontine_id (FK), user_id (FK)
├── montant, statut: ENUM('en_attente','confirme','echoue')
├── methode_paiement: ENUM('wave','orange_money')
├── reference (unique), receipt_url, webhook_data
└── paye_le, timestamps

sutura (urgences)
├── id, tontine_id (FK), demandeur_id (FK users) ← ANONYME côté API
├── montant_demande, motif
├── statut: ENUM('en_cours','approuve','rejete')
└── resultat_at, timestamps

sutura_votes
├── id, sutura_id (FK), user_id (FK)
├── approuve (boolean)
└── unique(sutura_id, user_id)

tirages
├── id, tontine_id (FK), gagnant_id (FK users)
├── tour, montant_attribue
└── timestamps

notifications
├── id, user_id (FK), type, titre, message
├── data (JSON), lu (boolean)
└── timestamps
```

---

## 🔒 6. SÉCURITÉ

- ✅ HTTPS obligatoire en production
- ✅ Laravel Passport (OAuth2) pour tous les endpoints
- ✅ OTP à 6 chiffres + expiration 10 minutes
- ✅ Validation stricte côté backend sur chaque endpoint
- ✅ Anonymat Sutura : `demandeur_id` jamais exposé dans l'API
- ✅ Vérification signature webhook (Wave/Orange Money)
- ✅ Un seul vote par membre par urgence (contrainte DB + logique)
- ✅ Soft deletes pour la traçabilité

---

## 🚀 7. DÉPLOIEMENT PRODUCTION

### Serveur recommandé
- VPS Ubuntu 22.04 (2 vCPU, 4GB RAM minimum)
- Nginx + PHP-FPM
- MySQL 8 + Redis
- SSL Let's Encrypt

### Nginx config

```nginx
server {
    listen 443 ssl;
    server_name api.tontine.sn;
    root /var/www/tontine/public;

    ssl_certificate /etc/letsencrypt/live/api.tontine.sn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.tontine.sn/privkey.pem;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### Supervisor (queue workers)

```ini
[program:tontine-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/tontine/artisan queue:work redis --sleep=3 --tries=3
autostart=true
autorestart=true
numprocs=2
```

---

## 📋 8. COMPLÉTION DU PROJET

| Module | Statut | Détail |
|--------|--------|--------|
| Auth + OTP | ✅ 100% | Provider connecté, 6 chiffres, expiration |
| Gestion rôles | ✅ 100% | Admin/Membre, navigation adaptée |
| Tontines CRUD | ✅ 95% | Créer, lister, membres, invitations |
| Cotisations | ✅ 90% | Wave + Orange Money, webhooks |
| Sutura (votes) | ✅ 95% | Anonymat, votes, résultat auto |
| Tirage | ✅ 85% | Aléatoire sécurisé, animations à brancher |
| Notifications | ✅ 90% | Firebase FCM + base de données |
| Dashboard | ✅ 85% | Stats admin/membre depuis API |
| PDF reçus | 🔧 60% | Package `pdf` configuré, à implémenter |
| Deep Links | 🔧 70% | `app_links` configuré, routing à tester |

**Estimation globale : ~88% complet**

Pour atteindre 100% :
1. Brancher les animations tirage (Flutter `AnimationController`)
2. Générer les reçus PDF avec le package `pdf`
3. Configurer Firebase et tester les push notifications
4. Tester les webhooks Wave/Orange Money avec ngrok en dev
