# 🚀 HTTPS automatisé pour application WSGI Python (Nginx + Let's Encrypt)

Ce script bash installe et configure intégralement une architecture **reverse proxy HTTPS** pour une application WSGI Python qui n’écoute encore sur aucun port HTTP/HTTPS.  
Il utilise **Gunicorn** (serveur WSGI), **Nginx** (proxy inverse) et **Certbot** (Let's Encrypt) avec renouvellement automatique des certificats.

## ✨ Fonctionnalités

- Installation automatique des paquets nécessaires (Nginx, Certbot, Gunicorn)
- Création d’un service **systemd** pour l’application WSGI
- Configuration de Nginx en reverse proxy (HTTP → localhost)
- Obtention gratuite d’un certificat SSL (Let's Encrypt)
- Redirection automatique HTTP → HTTPS
- Mise en place du renouvellement automatique des certificats
- Aucune intervention manuelle après l’exécution (interactive uniquement au début)

## 📋 Prérequis

- Un serveur **Linux** (Debian/Ubuntu recommandé) avec accès **root** (`sudo`)
- Un **nom de domaine** pointant vers l’IP publique du serveur (DNS déjà configuré)
- Les ports **80** et **443** ouverts dans le pare‑feu
- Votre application WSGI Python doit exister sous forme d’un **fichier .py** contenant une variable callable (ex: `app`)

## 🔧 Utilisation
1. **Téléchargez le script** sur votre serveur :
   ```bash
   wget https://raw.githubusercontent.com/sebastienbats/reverse-proxy-https-WSGI-python/main/setup_https_wsgi.sh
   ```
   ou créez le fichier manuellement avec nano/vim
2. Rendez-le exécutable :
  ```bash
  chmod +x setup_https_wsgi.sh
  ```
3. Exécutez-le en root :
  ```bash
  sudo ./setup_https_wsgi.sh
  ````
Répondez aux questions interactives :
- Nom de domaine (ex: app.example.com)
- Email pour Let's Encrypt (notifications de renouvellement)
- Chemin complet du fichier WSGI (ex: /opt/app/app.py)
- Nom de la variable WSGI dans ce fichier (souvent app)
- Port local pour l’application (par défaut 8000)
- Le script s’occupe du reste : installation, configuration, démarrage et activation HTTPS.

## 📁 Structure mise en place
### Composant	Rôle
- gunicorn:	Serveur WSGI exécutant votre application sur 127.0.0.1:8000
- systemd:	Gère le démarrage automatique et les redémarrages de Gunicorn
- Nginx:	Reverse proxy exposé sur les ports 80/443, sert le HTTPS
- Certbot:	Obtient et renouvelle les certificats SSL, configure Nginx
## 🧪 Vérification
Après exécution, testez l’accès sécurisé :
```bash
curl -I https://votredomaine.com          # Doit répondre en HTTPS
systemctl status wsgi_app                 # Vérifier que Gunicorn tourne
journalctl -u wsgi_app -n 20              # Logs de l'application
certbot certificates                      # Voir les certificats
```
## ⚙️ Personnalisation
- Nombre de workers Gunicorn : modifiez la ligne --workers 3 dans /etc/systemd/system/wsgi_app.service.
- Socket Unix (au lieu du port TCP) : remplacez --bind 127.0.0.1:8000 par --bind unix:/tmp/wsgi_app.sock et adaptez proxy_pass dans Nginx (proxy_pass http://unix:/tmp/wsgi_app.sock;).
- Environnement virtuel : ajoutez Environment="PATH=/home/user/venv/bin" et WorkingDirectory dans le fichier systemd.
- Nom du service : changez la variable APP_NAME en tête du script.

## 🔄 Renouvellement automatique
Certbot active un timer systemd (certbot.timer). Aucune action manuelle n’est requise.
Pour vérifier :
```bash
systemctl status certbot.timer
```
## ⚠️ Dépannage
### Problème	Solution possible
- Certbot échoue:
  Vérifiez que le domaine pointe vers le serveur (DNS) et que les ports 80/443 sont ouverts.
- L’application ne répond pas:
  journalctl -u wsgi_app pour voir les erreurs Python. Assurez-vous que le fichier WSGI est valide.
- Nginx ne redémarre pas:
  nginx -t pour tester la configuration, puis systemctl restart nginx.
- HTTPS fonctionne, mais pas HTTP → HTTPS	Certbot avec l’option --redirect le fait automatiquement.
  Vérifiez dans /etc/nginx/sites-available/votredomaine.
## 📄 Licence
MIT – libre d’utilisation et de modification.
