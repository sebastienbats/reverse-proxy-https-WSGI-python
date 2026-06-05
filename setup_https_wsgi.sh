#!/bin/bash
set -e

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Vérification root ---
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ce script doit être exécuté en tant que root (sudo).${NC}"
    exit 1
fi

# --- Variables ---
APP_NAME="wsgi_app"
WSGI_FILE=""
APP_PORT=8000
DOMAIN=""
EMAIL=""
APP_USER="${SUDO_USER:-$USER}"

# --- Fonctions d'aide ---
ask_domain() {
    read -p "Nom de domaine (ex: monapp.example.com) : " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Domaine requis.${NC}"
        exit 1
    fi
}

ask_email() {
    read -p "Email pour Let's Encrypt : " EMAIL
    if [[ -z "$EMAIL" ]]; then
        echo -e "${RED}Email requis.${NC}"
        exit 1
    fi
}

ask_wsgi_path() {
    echo -e "${YELLOW}Chemin vers votre fichier WSGI (ex: /home/user/monapp/app.py) :${NC}"
    read -e -p "> " WSGI_FILE
    if [[ ! -f "$WSGI_FILE" ]]; then
        echo -e "${RED}Fichier non trouvé.${NC}"
        exit 1
    fi
    # Extraire le nom de l'application (par défaut 'app')
    read -p "Nom de la variable WSGI (souvent 'app') : " WSGI_VAR
    WSGI_VAR="${WSGI_VAR:-app}"
}

ask_app_port() {
    read -p "Port local pour l'application (défaut 8000) : " APP_PORT
    APP_PORT="${APP_PORT:-8000}"
}

install_packages() {
    echo -e "${YELLOW}Mise à jour et installation des paquets...${NC}"
    apt update
    apt install -y nginx certbot python3-certbot-nginx python3-pip
    pip3 install gunicorn
    echo -e "${GREEN}Paquets installés.${NC}"
}

create_systemd_service() {
    local SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
    local APP_DIR=$(dirname "$WSGI_FILE")
    local APP_MODULE=$(basename "$WSGI_FILE" .py)

    echo -e "${YELLOW}Création du service systemd pour Gunicorn...${NC}"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Gunicorn instance pour $APP_NAME
After=network.target

[Service]
User=$APP_USER
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=/usr/local/bin:/usr/bin"
ExecStart=/usr/local/bin/gunicorn --workers 3 --bind 127.0.0.1:$APP_PORT ${APP_MODULE}:${WSGI_VAR}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$APP_NAME"
    systemctl start "$APP_NAME"
    echo -e "${GREEN}Service $APP_NAME démarré sur 127.0.0.1:$APP_PORT${NC}"
}

configure_nginx() {
    local NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    echo -e "${YELLOW}Configuration de Nginx pour $DOMAIN...${NC}"
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/"
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl reload nginx
    echo -e "${GREEN}Nginx prêt à servir HTTP.${NC}"
}

obtain_ssl() {
    echo -e "${YELLOW}Obtention du certificat SSL avec Certbot...${NC}"
    certbot --nginx --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN" --redirect
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Certificat SSL installé et redirection HTTP → HTTPS activée.${NC}"
    else
        echo -e "${RED}Certbot a échoué. Vérifiez que $DOMAIN pointe vers ce serveur (DNS) et que les ports 80/443 sont ouverts.${NC}"
        exit 1
    fi
}

final_info() {
    echo -e "\n${GREEN}=== Installation terminée ===${NC}"
    echo -e "Application WSGI : $WSGI_FILE (variable $WSGI_VAR)"
    echo -e "Service systemd : ${APP_NAME}.service (écoute sur 127.0.0.1:$APP_PORT)"
    echo -e "Site HTTPS : https://$DOMAIN"
    echo -e "Renouvellement automatique : activé (certbot.timer)"
    echo -e "\nCommandes utiles :"
    echo -e "  sudo systemctl status $APP_NAME   # Voir l'état de l'application"
    echo -e "  sudo journalctl -u $APP_NAME -f   # Logs de l'application"
    echo -e "  sudo systemctl restart nginx      # Redémarrer Nginx"
}

# --- Exécution principale ---
main() {
    echo -e "${GREEN}Configuration automatique d'un reverse proxy HTTPS pour application WSGI${NC}"
    ask_domain
    ask_email
    ask_wsgi_path
    ask_app_port
    install_packages
    create_systemd_service
    configure_nginx
    obtain_ssl
    final_info
}

main
