#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root (sudo)." >&2
    exit 1
fi

if [[ ! -f "${PROJECT_ROOT}/composer.json" ]]; then
    echo "composer.json not found — run this script from the repository root (e.g. sudo bash deploy/install_panel.sh)." >&2
    exit 1
fi

log() {
    local colour_reset="\033[0m"
    local colour_info="\033[1;34m"
    printf "%b[INFO]%b %s\n" "${colour_info}" "${colour_reset}" "$1"
}

prompt_default() {
    local prompt="$1"
    local default="$2"
    local var
    read -rp "${prompt} [${default}]: " var
    printf '%s' "${var:-$default}"
}

prompt_secret() {
    local prompt="$1"
    local var
    read -rsp "${prompt}: " var
    printf '\n'
    printf '%s' "${var}"
}

sql_escape() {
    local input="$1"
    input="${input//\\/\\\\}"
    input="${input//\'/\'\'}"
    printf "%s" "${input}"
}

update_env() {
    local key="$1"
    local value="$2"
    local file="${3:-${PROJECT_ROOT}/.env}"
    local escaped="${value//\\/\\\\}"
    escaped="${escaped//&/\\&}"
    escaped="${escaped//\//\\/}"

    if grep -q "^${key}=" "${file}" 2>/dev/null; then
        sed -i "s#^${key}=.*#${key}=${escaped}#" "${file}"
    else
        printf "%s=%s\n" "${key}" "${value}" >> "${file}"
    fi
}

ensure_packages() {
    log "Updating apt repositories"
    apt-get update -y

    log "Installing base packages"
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl wget zip unzip git gnupg software-properties-common ca-certificates lsb-release gettext-base

    if ! systemctl is-enabled --quiet mariadb 2>/dev/null; then
        log "Installing MariaDB server"
        DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client
        systemctl enable --now mariadb
    fi

    if ! systemctl is-enabled --quiet redis-server 2>/dev/null; then
        log "Installing Redis"
        DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server
        systemctl enable --now redis-server
    fi

    if ! command -v php >/dev/null || ! php -v | grep -q "8.2"; then
        log "Adding PHP 8.2 repository"
        add-apt-repository -y ppa:ondrej/php
        apt-get update -y
    fi

    log "Installing PHP 8.2 and extensions"
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        php8.2 php8.2-cli php8.2-fpm php8.2-common php8.2-curl php8.2-mbstring php8.2-mysql php8.2-xml \
        php8.2-zip php8.2-gmp php8.2-bcmath php8.2-intl php8.2-sqlite3 php8.2-redis php8.2-imagick

    systemctl enable --now php8.2-fpm

    log "Installing Node.js 20.x"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
    corepack enable

    if ! command -v composer >/dev/null; then
        log "Installing Composer"
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
    fi
}

tune_php() {
    local ini="/etc/php/8.2/fpm/php.ini"
    log "Tuning PHP configuration (${ini})"
    sed -i "s/^memory_limit = .*/memory_limit = 512M/" "${ini}"
    sed -i "s/^post_max_size = .*/post_max_size = 128M/" "${ini}"
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 128M/" "${ini}"
    sed -i "s/^max_execution_time = .*/max_execution_time = 120/" "${ini}"
    systemctl restart php8.2-fpm
}

ensure_env_file() {
    cd "${PROJECT_ROOT}"
    if [[ ! -f .env ]]; then
        if [[ ! -f .env.example ]]; then
            log "Downloading upstream .env.example"
            curl -fsSL https://raw.githubusercontent.com/pterodactyl/panel/v1.11.8/.env.example -o .env.example
        fi
        log "Creating .env from template"
        cp .env.example .env
    fi

    mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views
    chown -R www-data:www-data storage bootstrap/cache || true
    chmod -R 755 storage bootstrap/cache
}

configure_database() {
    local db_name db_user db_pass
    db_name="$(prompt_default "Database name" "pterodactyl")"
    db_user="$(prompt_default "Database user" "ptero")"
    db_pass="$(prompt_secret "Database password (leave blank to generate)")"
    if [[ -z "${db_pass}" ]]; then
        db_pass="$(openssl rand -base64 18 | tr -d '=+/')"
        log "Generated database password: ${db_pass}"
    fi

    mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${db_user}'@'127.0.0.1' IDENTIFIED BY '$(sql_escape "${db_pass}")';
CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '$(sql_escape "${db_pass}")';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';
FLUSH PRIVILEGES;
SQL

    update_env "DB_HOST" "127.0.0.1"
    update_env "DB_PORT" "3306"
    update_env "DB_DATABASE" "${db_name}"
    update_env "DB_USERNAME" "${db_user}"
    update_env "DB_PASSWORD" "${db_pass}"
}

configure_app_env() {
    local system_tz default_url egg_email panel_domain
    system_tz="$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")"
    local default_ip
    default_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    default_url="http://${default_ip:-panel.example.com}"

    egg_email="$(prompt_default "Egg author email" "admin@example.com")"
    local app_url
    app_url="$(prompt_default "Panel URL" "${default_url}")"
    local app_timezone
    app_timezone="$(prompt_default "Application timezone" "${system_tz}")"
    panel_domain="$(prompt_default "Nginx server_name (use _ for wildcard)" "_")"

    update_env "APP_ENV" "production"
    update_env "APP_DEBUG" "false"
    update_env "APP_URL" "${app_url}"
    update_env "APP_TIMEZONE" "${app_timezone}"
    update_env "MAIL_FROM_ADDRESS" "${egg_email}"
    update_env "MAIL_FROM_NAME" "Pterodactyl"
    update_env "APP_SERVICE_AUTHOR" "${egg_email}"

    update_env "CACHE_DRIVER" "redis"
    update_env "SESSION_DRIVER" "redis"
    update_env "QUEUE_CONNECTION" "redis"
    update_env "TELEMETRY_ENABLED" "true"
    update_env "REDIS_HOST" "127.0.0.1"
    update_env "REDIS_PORT" "6379"
    update_env "REDIS_PASSWORD" ""

    echo "${panel_domain}"
}

run_composer_and_yarn() {
    local app_user="${SUDO_USER:-$(stat -c '%U' "${PROJECT_ROOT}")}"
    if [[ -z "${app_user}" ]]; then
        app_user="root"
    fi

    log "Running composer install"
    if [[ "${app_user}" == "root" ]]; then
        (cd "${PROJECT_ROOT}" && composer install --no-dev --optimize-autoloader)
    else
        runuser -u "${app_user}" -- bash -lc "cd '${PROJECT_ROOT}' && composer install --no-dev --optimize-autoloader"
    fi

    log "Generating application key"
    (cd "${PROJECT_ROOT}" && php artisan key:generate --force)

    log "Installing yarn dependencies"
    if [[ "${app_user}" == "root" ]]; then
        (cd "${PROJECT_ROOT}" && yarn install --freeze-lockfile)
        (cd "${PROJECT_ROOT}" && NODE_OPTIONS=--openssl-legacy-provider yarn build)
    else
        runuser -u "${app_user}" -- bash -lc "cd '${PROJECT_ROOT}' && yarn install --freeze-lockfile"
        runuser -u "${app_user}" -- bash -lc "cd '${PROJECT_ROOT}' && NODE_OPTIONS=--openssl-legacy-provider yarn build"
    fi
}

run_migrations() {
    log "Running database migrations"
    (cd "${PROJECT_ROOT}" && php artisan migrate --seed --force)
}

apply_permissions() {
    log "Setting application permissions"
    chown -R www-data:www-data "${PROJECT_ROOT}"
    chmod -R 755 "${PROJECT_ROOT}/storage" "${PROJECT_ROOT}/bootstrap/cache"
}

install_queue_service() {
    log "Installing queue worker systemd unit"
    install -Dm644 "${PROJECT_ROOT}/deploy/systemd/pteroq.service" /etc/systemd/system/pteroq.service
    systemctl daemon-reload
    systemctl enable --now pteroq
}

install_cron() {
    log "Adding Laravel scheduler cron task"
    local cron_job="* * * * * php ${PROJECT_ROOT}/artisan schedule:run >> /dev/null 2>&1"
    local tmpfile
    tmpfile="$(mktemp)"
    if crontab -l 2>/dev/null | grep -v "artisan schedule:run" > "${tmpfile}"; then
        :
    else
        : > "${tmpfile}"
    fi
    if ! grep -Fxq "${cron_job}" "${tmpfile}"; then
        echo "${cron_job}" >> "${tmpfile}"
    fi
    crontab "${tmpfile}"
    rm -f "${tmpfile}"
}

install_nginx() {
    local panel_domain="$1"
    log "Installing nginx"
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
    local template="${PROJECT_ROOT}/deploy/nginx/pterodactyl.conf"
    local target="/etc/nginx/sites-available/pterodactyl.conf"
    local server_name="${panel_domain}"
    [[ -z "${server_name}" ]] && server_name="_"
    SERVER_NAME="${server_name}" envsubst '${SERVER_NAME}' < "${template}" > "${target}"
    ln -sf "${target}" /etc/nginx/sites-enabled/pterodactyl.conf
    nginx -t
    systemctl restart nginx
}

maybe_install_wings() {
    local choice
    read -rp "Install Pterodactyl Wings (game daemon) on this machine? [y/N]: " choice
    choice="${choice,,}"
    if [[ "${choice}" != "y" ]]; then
        log "Skipping Wings installation"
        return
    fi

    log "Installing Docker"
    if ! command -v docker >/dev/null; then
        curl -fsSL https://get.docker.com/ | sh
        systemctl enable --now docker
    fi

    log "Installing Wings binary"
    curl -fsSL https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
    chmod +x /usr/local/bin/wings
    mkdir -p /etc/pterodactyl

    install -Dm644 "${PROJECT_ROOT}/deploy/systemd/wings.service" /etc/systemd/system/wings.service
    systemctl daemon-reload
    if [[ -f /etc/pterodactyl/config.yml ]]; then
        systemctl enable --now wings
    else
        systemctl enable wings
        log "Wings service installed. Generate the node configuration in the panel and place it at /etc/pterodactyl/config.yml, then run: systemctl restart wings"
    fi
}

main() {
    ensure_packages
    tune_php
    ensure_env_file

    log "Configuring MariaDB"
    configure_database

    log "Configuring application environment"
    local panel_domain
    panel_domain="$(configure_app_env)"

    run_composer_and_yarn
    run_migrations
    apply_permissions
    install_queue_service
    install_cron
    install_nginx "${panel_domain}"
    maybe_install_wings

    log "Installation complete."
    echo
    echo "Next steps:"
    echo "  1. Run 'php artisan p:user:make' to create your first admin user."
    echo "  2. Update /etc/pterodactyl/config.yml using the node configuration from the panel, then restart wings if installed."
    echo "  3. Point your DNS at this server and obtain HTTPS certificates (e.g. certbot --nginx)."
}

main "$@"

