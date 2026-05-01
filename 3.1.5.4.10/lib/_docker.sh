#!/bin/bash
#
# Rotina BETA: instalação via Docker Compose
# Sobe backend + frontend + frontnovo em containers Docker.
# nginx existente é usado como proxy SSL (certbot), sem conflito de porta.
# Traefik NÃO é iniciado nesta rotina (nginx já faz proxy + SSL).
#
# Portas host expostas pelos containers:
#   backend  → 7563
#   frontend → 7564 (mapeia container 4444)
#   frontnovo→ 7565 (mapeia container 3000)

# DOCKER_DIR é resolvido em docker_ensure_extracted:
#   - /home/deployzdg/zpro.io  se o install PM2 já existe (deployzdg presente)
#   - /root/zpro.io            se é instalação Docker standalone (sem deployzdg)
DOCKER_DIR=""

#######################################
# Beta warning para instalação Docker
# Arguments:
#   None
#######################################
docker_warn_beta() {
  print_banner
  printf "${YELLOW}  ⚠️   ATENÇÃO — Instalação Docker está em BETA${NC}\n\n"
  printf "${LINE}\n"
  printf "  ${WHITE}Esta rotina sobe backend + frontend + frontendNovo em containers Docker.${NC}\n\n"
  printf "  ${CYAN_LIGHT}Arquitetura:${NC}\n"
  printf "  ${DIM}• nginx (já instalado) faz SSL + proxy → containers Docker${NC}\n"
  printf "  ${DIM}• Traefik NÃO é usado — nginx ocupa as portas 80/443${NC}\n"
  printf "  ${DIM}• Portas host: selecionadas interativamente (padrão 7563/7564/7565/7544)${NC}\n\n"
  printf "  ${YELLOW}⚠️   CORS (SECURE_URL=*):${NC}\n"
  printf "  ${WHITE}O backend Docker receberá SECURE_URL=* para permitir o frontendNovo.${NC}\n"
  printf "  ${RED}   Revise antes de usar em produção com dados sensíveis.${NC}\n\n"
  printf "  ${YELLOW}⚠️   NEXT_PUBLIC_* são baked-in no build:${NC}\n"
  printf "  ${WHITE}Se trocar a URL do backend, é necessário rebuild do container frontnovo.${NC}\n\n"
  printf "  ${DIM}Se a instalação falhar, siga o tutorial em:${NC}\n"
  printf "  ${GREEN}https://zpro.passaportezdg.com.br/${NC}\n"
  printf "${LINE}\n\n"
  printf "  ${YELLOW}Pressione ENTER para continuar ou Ctrl+C para cancelar...${NC}\n"
  read -r
}

#######################################
# Verifica se Docker e Docker Compose estão instalados
# Arguments:
#   None
#######################################
docker_check_requirements() {
  step_header "🐳" "Verificando Docker" \
    "Verifica se Docker e docker compose estão disponíveis."
  printf "\n"

  if ! command -v docker &>/dev/null; then
    printf "  ${RED}❌  Docker não encontrado. Instale via opção [5] do sistema ou:${NC}\n"
    printf "  ${DIM}curl -fsSL https://get.docker.com | sh${NC}\n\n"
    return 1
  fi

  if ! docker compose version &>/dev/null; then
    printf "  ${RED}❌  'docker compose' (v2) não encontrado.${NC}\n"
    printf "  ${DIM}Instale o plugin: apt-get install -y docker-compose-plugin${NC}\n\n"
    return 1
  fi

  local _docker_version
  _docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
  printf "  ${GREEN}✅${NC}  Docker ${_docker_version} encontrado.\n\n"
  sleep 1
}

#######################################
# Retorna a próxima porta TCP livre a partir de $1
# Arguments:
#   $1 — porta inicial
#######################################
_docker_next_free_port() {
  local _p=$1
  while ss -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${_p}$"; do
    _p=$((_p + 1))
  done
  echo "$_p"
}

#######################################
# Seleciona portas para os containers Docker.
# Para cada porta padrão, se estiver em uso mostra o processo,
# sugere a próxima livre e permite ao usuário confirmar ou digitar outra.
# Sets: docker_backend_port, docker_frontend_port,
#       docker_frontnovo_port, docker_db_port
# Arguments:
#   None
#######################################
docker_select_ports() {
  step_header "🔍" "Selecionando portas para os containers Docker" \
    "Detecta conflitos com PM2 ou outros serviços e resolve interativamente."
  printf "  ${DIM}PM2 usa 3000/4444 — portas Docker são diferentes por design.${NC}\n\n"

  # helper: pergunta porta para um serviço
  # $1=nome  $2=porta padrão  → echo porta escolhida
  _ask_port() {
    local _name="$1"
    local _default="$2"
    local _pid _proc _suggested _input

    _pid=$(ss -tlnp 2>/dev/null | awk -v p=":${_default}$" '$4 ~ p {match($0,/pid=([0-9]+)/,a); print a[1]}' | head -1)

    if [ -z "$_pid" ]; then
      printf "  ${GREEN}%-7s${NC}  %-22s ${GREEN}livre${NC} — usando %s\n" "$_default" "$_name" "$_default"
      echo "$_default"
      return
    fi

    _proc=$(ps -p "$_pid" -o comm= 2>/dev/null || echo "pid $_pid")
    _suggested=$(_docker_next_free_port $((_default + 1)))
    printf "  ${RED}%-7s${NC}  %-22s ${RED}EM USO${NC} por: %s\n" "$_default" "$_name" "$_proc"
    printf "         ${DIM}Próxima livre: ${_suggested}${NC}\n"
    printf "         Digite a porta desejada [Enter = %s]: " "$_suggested"
    read -r _input
    if [ -z "$_input" ]; then
      _input="$_suggested"
    fi
    # valida que é número e está livre
    if ! [[ "$_input" =~ ^[0-9]+$ ]] || [ "$_input" -lt 1024 ] || [ "$_input" -gt 65535 ]; then
      printf "  ${RED}Porta inválida. Usando %s.${NC}\n" "$_suggested"
      _input="$_suggested"
    fi
    echo "$_input"
  }

  printf "  ${WHITE}%-7s  %-22s  Status${NC}\n" "Porta" "Serviço"
  printf "  ${LINE}\n"

  docker_backend_port=$(_ask_port  "backend Docker"       7563)
  docker_frontend_port=$(_ask_port "frontend Docker"      7564)
  docker_frontnovo_port=$(_ask_port "frontendNovo Docker" 7565)
  docker_db_port=$(_ask_port       "PostgreSQL Docker"    7544)

  printf "\n"
  printf "  ${GREEN}✅${NC}  Portas definidas:\n"
  printf "  ${DIM}backend=%s  frontend=%s  frontNovo=%s  postgres=%s${NC}\n\n" \
    "$docker_backend_port" "$docker_frontend_port" "$docker_frontnovo_port" "$docker_db_port"
  sleep 1
}

#######################################
# Coleta domínios e email para o deploy Docker
# Sets: docker_backend_domain, docker_frontend_domain,
#       docker_frontnovo_domain, docker_backend_url,
#       docker_frontend_url, docker_frontnovo_url
# Arguments:
#   None
#######################################
docker_get_domains() {
  print_banner
  printf "${WHITE}  💻 Domínio do Backend Docker (ex: dockerapi.cliente.com.br):${GRAY_LIGHT}"
  printf "\n\n"
  read -p "  > " docker_backend_domain
  if ! validate_dns "$docker_backend_domain"; then
    docker_get_domains
    return
  fi
  docker_backend_url="https://${docker_backend_domain}"

  print_banner
  printf "${WHITE}  💻 Domínio do Frontend Docker (ex: dockerapp.cliente.com.br):${GRAY_LIGHT}"
  printf "\n\n"
  read -p "  > " docker_frontend_domain
  if ! validate_dns "$docker_frontend_domain"; then
    docker_get_domains
    return
  fi
  docker_frontend_url="https://${docker_frontend_domain}"

  print_banner
  printf "${WHITE}  💻 Domínio do frontendNovo Docker (deixe em branco para pular):${GRAY_LIGHT}"
  printf "\n\n"
  read -p "  > " docker_frontnovo_domain
  if [ -n "$docker_frontnovo_domain" ]; then
    if ! validate_dns "$docker_frontnovo_domain"; then
      docker_get_domains
      return
    fi
    docker_frontnovo_url="https://${docker_frontnovo_domain}"
  else
    docker_frontnovo_url=""
  fi
}

#######################################
# Garante que os arquivos da aplicação estão disponíveis para o Docker build.
# Define DOCKER_DIR dinamicamente:
#   - /home/deployzdg/zpro.io  se PM2 já instalado (reaproveita arquivos existentes)
#   - /root/zpro.io            standalone Docker — extrai como root, sem deployzdg
# Arguments:
#   None
#######################################
docker_ensure_extracted() {
  step_header "📦" "Verificando arquivos da aplicação" \
    "Localiza ou extrai backend/, frontend/, frontNovo/ para o Docker build."
  printf "\n"

  # Cenário 1: install PM2 anterior — arquivos já prontos
  if [ -d "/home/deployzdg/zpro.io/backend" ]; then
    DOCKER_DIR="/home/deployzdg/zpro.io"
    printf "  ${GREEN}✅${NC}  Usando arquivos existentes em ${DOCKER_DIR}\n\n"
    sleep 1
    return 0
  fi

  # Cenário 2: Docker standalone — extrai como root em /root/zpro.io
  DOCKER_DIR="/root/zpro.io"
  printf "  ${YELLOW}⚠️   Arquivos não encontrados — extraindo zpro.zip como root...${NC}\n\n"

  # Copia zip se ainda não está em /root/
  if [ ! -f "/root/zpro.zip" ]; then
    start_spinner "Copiando zpro.zip para /root/..."
    sudo su - root <<EOF
    cp "${PROJECT_ROOT}/zpro.zip" /root/zpro.zip
EOF
    stop_spinner "zpro.zip copiado para /root/."
  fi

  start_spinner "Extraindo zpro.zip em /root/..."
  sudo su - root <<EOF
  cd /root
  unzip -q zpro.zip
EOF
  if [ $? -ne 0 ]; then
    stop_spinner_error "Falha ao extrair zpro.zip."
    log_error "unzip zpro docker" "Falha ao extrair zpro.zip em /root"
    return 1
  fi
  stop_spinner "Arquivos extraídos em ${DOCKER_DIR}."
  sleep 1
}

#######################################
# Prepara diretório e arquivo .env do Docker
# Arguments:
#   None
#######################################
docker_prepare_env() {
  step_header "⚙️ " "Preparando ambiente Docker" \
    "Gera ${DOCKER_DIR}/.env.docker para o docker-compose."
  printf "\n"

  local _pg_pass
  _pg_pass=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)
  local _jwt_secret
  _jwt_secret=$(openssl rand -base64 32)
  local _jwt_refresh_secret
  _jwt_refresh_secret=$(openssl rand -base64 32)

  # Se FRONTEND_URL_2 for o frontnovo, configura SECURE_URL
  local _frontend_url_2=""
  local _secure_url=""
  if [ -n "${docker_frontnovo_url:-}" ]; then
    _frontend_url_2="${docker_frontnovo_url}"
    _secure_url="*"
  fi

sudo su - root <<EOF
  cat <<[-]EOF > "${DOCKER_DIR}/.env.docker"
# Backend
BACKEND_URL=${docker_backend_url}
BACKEND_DOMAIN=${docker_backend_domain}
FRONTEND_URL=${docker_frontend_url}
FRONTEND_DOMAIN=${docker_frontend_domain}

# frontendNovo (beta)
FRONTNOVO_DOMAIN=${docker_frontnovo_domain}
FRONTEND_URL_2=${_frontend_url_2}
SECURE_URL=${_secure_url}

# Portas host (configuradas na seleção de portas)
BACKEND_PORT=${docker_backend_port}
FRONTEND_PORT=${docker_frontend_port}
FRONTNOVO_PORT=${docker_frontnovo_port}
DB_PORT=${docker_db_port}

# Banco de dados
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${_pg_pass}
POSTGRES_DB=postgres

# JWT
JWT_SECRET=${_jwt_secret}
JWT_REFRESH_SECRET=${_jwt_refresh_secret}

# Let's Encrypt
ACME_EMAIL=${deploy_email}

# Misc
NODE_ENV=production
[-]EOF
EOF

  printf "  ${GREEN}✅${NC}  ${DOCKER_DIR}/.env.docker criado.\n\n"
  sleep 1
}

#######################################
# Copia docker-compose.yml para o diretório Docker
# Arguments:
#   None
#######################################
docker_copy_compose() {
  step_header "📋" "Copiando docker-compose.yml" \
    "Copia ${PROJECT_ROOT}/docker-compose.yml para ${DOCKER_DIR}/."
  printf "\n"

  sudo su - root <<EOF
  cp "${PROJECT_ROOT}/docker-compose.yml" "${DOCKER_DIR}/docker-compose.yml"
EOF

  printf "  ${GREEN}✅${NC}  docker-compose.yml copiado para ${DOCKER_DIR}/\n\n"
  sleep 1
}

#######################################
# Sobe os containers Docker (sem Traefik — nginx faz proxy)
# Arguments:
#   None
#######################################
docker_compose_up() {
  step_header "🐳" "Subindo containers Docker" \
    "Executa docker compose up com build — pode levar vários minutos."
  printf "  ${DIM}Serviços: postgres, backend, frontend$([ -n "${docker_frontnovo_domain:-}" ] && echo ', frontnovo')${NC}\n"
  printf "  ${DIM}Traefik NÃO é iniciado — nginx é o proxy.${NC}\n\n"

  # Lista de serviços a subir (sem traefik)
  local _services="postgres backend frontend"
  if [ -n "${docker_frontnovo_domain:-}" ]; then
    _services="$_services frontnovo"
  fi

  start_spinner "Executando docker compose up --build (pode demorar 10-20 min no primeiro build)..."
  sudo su - root <<EOF
  cd "${DOCKER_DIR}"
  docker compose --env-file .env.docker up -d --build ${_services}
EOF
  if [ $? -ne 0 ]; then
    stop_spinner_error "Falha ao subir containers Docker. Verifique: docker compose logs"
    log_error "docker compose up" "Falha ao subir containers em ${DOCKER_DIR}"
  else
    stop_spinner "Containers Docker iniciados com sucesso."
  fi
  sleep 2
}

#######################################
# Configura nginx para proxiar os containers Docker
# Arguments:
#   None
#######################################
docker_nginx_setup() {
  step_header "🌐" "Configurando nginx para os containers Docker" \
    "Cria vhosts: backend→${docker_backend_port}, frontend→${docker_frontend_port}$([ -n "${docker_frontnovo_domain:-}" ] && echo ", frontNovo→${docker_frontnovo_port}")."
  printf "\n"

  sleep 1

sudo su - root << EOF

# ── Backend Docker ──────────────────────────────────────────
cat > /etc/nginx/sites-available/zpro-docker-backend << 'END'
server {
  server_name ${docker_backend_domain};

  location /.well-known/acme-challenge/ {
    proxy_pass http://127.0.0.1:81;
  }

  location / {
    proxy_pass http://127.0.0.1:${docker_backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
  }
}
END
ln -sf /etc/nginx/sites-available/zpro-docker-backend /etc/nginx/sites-enabled/zpro-docker-backend

# ── Frontend Docker ─────────────────────────────────────────
cat > /etc/nginx/sites-available/zpro-docker-frontend << 'END'
server {
  server_name ${docker_frontend_domain};

  location /.well-known/acme-challenge/ {
    proxy_pass http://127.0.0.1:81;
  }

  location / {
    proxy_pass http://127.0.0.1:${docker_frontend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
  }
}
END
ln -sf /etc/nginx/sites-available/zpro-docker-frontend /etc/nginx/sites-enabled/zpro-docker-frontend

EOF

  # frontnovo nginx vhost (opcional)
  if [ -n "${docker_frontnovo_domain:-}" ]; then
sudo su - root << EOF

cat > /etc/nginx/sites-available/zpro-docker-frontnovo << 'END'
server {
  server_name ${docker_frontnovo_domain};

  location /.well-known/acme-challenge/ {
    proxy_pass http://127.0.0.1:81;
  }

  location / {
    proxy_pass http://127.0.0.1:${docker_frontnovo_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
  }
}
END
ln -sf /etc/nginx/sites-available/zpro-docker-frontnovo /etc/nginx/sites-enabled/zpro-docker-frontnovo

EOF
  fi

  sudo nginx -t && sudo systemctl reload nginx

  printf "  ${GREEN}✅${NC}  vhosts Docker criados e nginx recarregado.\n\n"
  sleep 1
}

#######################################
# Emite SSL para os domínios Docker via certbot
# Arguments:
#   None
#######################################
docker_certbot_setup() {
  step_header "🔒" "Emitindo certificados SSL para os domínios Docker" \
    "Certbot via nginx para backend, frontend e frontnovo Docker."
  printf "\n"

  local _domains="${docker_backend_domain},${docker_frontend_domain}"
  if [ -n "${docker_frontnovo_domain:-}" ]; then
    _domains="${_domains},${docker_frontnovo_domain}"
  fi

  printf "  ${DIM}Domínios: ${_domains}${NC}\n\n"

  start_spinner "Emitindo certificados SSL..."
  sudo su - root <<EOF
  certbot -m "${deploy_email}" \
          --nginx \
          --agree-tos \
          --redirect \
          --non-interactive \
          --domains "${_domains}"
EOF
  if [ $? -ne 0 ]; then
    stop_spinner_error "Falha ao emitir SSL. Verifique DNS e tente novamente."
    log_error "certbot docker" "Falha ao emitir SSL para ${_domains}"
  else
    stop_spinner "Certificados SSL emitidos para os domínios Docker."
  fi
  sleep 1
}

#######################################
# Exibe mensagem de sucesso da instalação Docker
# Arguments:
#   None
#######################################
docker_install_success() {
  print_banner
  printf "${GREEN}  ✅  Instalação Docker concluída!${NC}\n\n"
  printf "${LINE}\n"
  printf "${WHITE}  📊 Serviços em execução:${NC}\n\n"
  printf "  • Backend   : ${GREEN}${docker_backend_url}${NC}  ${DIM}(host:${docker_backend_port})${NC}\n"
  printf "  • Frontend  : ${GREEN}${docker_frontend_url}${NC}  ${DIM}(host:${docker_frontend_port})${NC}\n"
  if [ -n "${docker_frontnovo_domain:-}" ]; then
    printf "  • frontNovo : ${GREEN}${docker_frontnovo_url}${NC}  ${DIM}(host:${docker_frontnovo_port})${NC}  ${YELLOW}[BETA]${NC}\n"
  fi
  printf "\n"
  printf "  ${DIM}Gerenciar containers:${NC}\n"
  printf "  ${DIM}  cd ${DOCKER_DIR} && docker compose --env-file .env.docker ps${NC}\n"
  printf "  ${DIM}  docker compose --env-file .env.docker logs -f backend${NC}\n"
  printf "  ${DIM}  docker compose --env-file .env.docker down   # parar tudo${NC}\n\n"
  printf "  ${YELLOW}⚠️   frontendNovo está em BETA — NEXT_PUBLIC_* são fixos no build.${NC}\n"
  printf "  ${DIM}Para trocar a URL do backend, faça rebuild:${NC}\n"
  printf "  ${DIM}  cd ${DOCKER_DIR} && docker compose --env-file .env.docker up -d --build frontnovo${NC}\n\n"
  printf "  ${GREEN}FAQ: https://zpro.passaportezdg.com.br/${NC}\n"
  printf "  ${GREEN}Suporte: https://passaportezdg.tomticket.com/${NC}\n"
  printf "${LINE}\n\n"

  show_error_summary
  sleep 2
}

#######################################
# Fluxo completo de instalação Docker (beta)
# Arguments:
#   None
#######################################
install_docker_zpro() {
  init_error_log "docker_install"
  warn_snapshot_required "instalação Docker (beta)" || return 1
  docker_warn_beta
  docker_check_requirements || return 1
  docker_select_ports || return 1
  docker_ensure_extracted || return 1
  docker_get_domains
  frontnovo_get_email
  docker_prepare_env
  docker_copy_compose
  docker_compose_up
  docker_nginx_setup
  docker_certbot_setup
  docker_install_success
}

#######################################
# Detecta onde o Docker foi instalado e define DOCKER_DIR
# Procura .env.docker em /home/deployzdg/zpro.io e /root/zpro.io
# Arguments:
#   None
#######################################
docker_detect_dir() {
  if [ -f "/home/deployzdg/zpro.io/.env.docker" ]; then
    DOCKER_DIR="/home/deployzdg/zpro.io"
  elif [ -f "/root/zpro.io/.env.docker" ]; then
    DOCKER_DIR="/root/zpro.io"
  else
    printf "  ${RED}❌  Instalação Docker não encontrada.${NC}\n"
    printf "  ${DIM}Nenhum .env.docker em /home/deployzdg/zpro.io ou /root/zpro.io${NC}\n\n"
    return 1
  fi
  printf "  ${GREEN}✅${NC}  Instalação Docker encontrada em: ${DOCKER_DIR}\n\n"
  sleep 1
}

#######################################
# Para os containers Docker antes do update
# Arguments:
#   None
#######################################
docker_stop_containers() {
  step_header "⏹️ " "Parando containers Docker" \
    "Executa docker compose stop para permitir a atualização dos arquivos."
  printf "\n"

  start_spinner "Parando containers em ${DOCKER_DIR}..."
  sudo su - root <<EOF
  cd "${DOCKER_DIR}"
  docker compose --env-file .env.docker stop
EOF
  stop_spinner "Containers parados."
  sleep 1
}

#######################################
# Remove source antigo e extrai update.zip
# Mantém .env.docker, docker-compose.yml e volumes intactos
# Arguments:
#   None
#######################################
docker_update_extract() {
  step_header "📦" "Atualizando arquivos fonte" \
    "Remove source antigo e extrai update.zip em ${DOCKER_DIR}."
  printf "  ${DIM}.env.docker e volumes Docker são preservados.${NC}\n\n"

  start_spinner "Removendo backend/, frontend/, frontNovo/ antigos..."
  sudo su - root <<EOF
  cd "${DOCKER_DIR}"
  rm -rf backend frontend frontNovo
EOF
  stop_spinner "Source antigo removido."

  # Copia update.zip
  start_spinner "Copiando update.zip para ${DOCKER_DIR}..."
  sudo su - root <<EOF
  cp "${PROJECT_ROOT}/update.zip" "${DOCKER_DIR}/update.zip"
EOF
  stop_spinner "update.zip copiado."

  # Extrai
  start_spinner "Extraindo update.zip..."
  sudo su - root <<EOF
  cd "${DOCKER_DIR}"
  unzip -q update.zip
  rm -f update.zip
EOF
  if [ $? -ne 0 ]; then
    stop_spinner_error "Falha ao extrair update.zip."
    log_error "unzip update docker" "Falha ao extrair update.zip em ${DOCKER_DIR}"
    return 1
  fi
  stop_spinner "Arquivos atualizados em ${DOCKER_DIR}."
  sleep 1
}

#######################################
# Rebuilda e reinicia os containers com o novo código
# Arguments:
#   None
#######################################
docker_compose_rebuild() {
  step_header "🔨" "Rebuilding e reiniciando containers" \
    "docker compose up --build com o novo código — pode levar vários minutos."
  printf "  ${DIM}As imagens serão reconstruídas; volumes de dados são preservados.${NC}\n\n"

  start_spinner "Executando docker compose up --build (aguarde)..."
  sudo su - root <<EOF
  cd "${DOCKER_DIR}"
  docker compose --env-file .env.docker up -d --build
EOF
  if [ $? -ne 0 ]; then
    stop_spinner_error "Falha ao rebuildar containers. Verifique: docker compose logs"
    log_error "docker compose rebuild" "Falha ao rebuildar em ${DOCKER_DIR}"
  else
    stop_spinner "Containers rebuilados e reiniciados."
  fi
  sleep 2
}

#######################################
# Mensagem de sucesso do update Docker
# Arguments:
#   None
#######################################
docker_update_success() {
  print_banner
  printf "${GREEN}  ✅  Update Docker concluído!${NC}\n\n"
  printf "${LINE}\n"
  printf "${WHITE}  📊 Containers atualizados:${NC}\n\n"

  sudo su - root <<'EOF'
  cd "${DOCKER_DIR}" 2>/dev/null || true
  docker compose --env-file .env.docker ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
EOF

  printf "\n"
  printf "  ${DIM}Logs: cd ${DOCKER_DIR} && docker compose --env-file .env.docker logs -f${NC}\n\n"
  printf "  ${YELLOW}⚠️   frontendNovo: NEXT_PUBLIC_* são baked-in no build.${NC}\n"
  printf "  ${DIM}Se a URL do backend mudou, edite .env.docker e rebuilde manualmente.${NC}\n\n"
  printf "  ${GREEN}FAQ: https://zpro.passaportezdg.com.br/${NC}\n"
  printf "  ${GREEN}Suporte: https://passaportezdg.tomticket.com/${NC}\n"
  printf "${LINE}\n\n"

  show_error_summary
  sleep 2
}

#######################################
# Fluxo completo de update Docker
# Arguments:
#   None
#######################################
update_docker_zpro() {
  init_error_log "docker_update"
  warn_snapshot_required "atualização Docker (beta)" || return 1
  docker_warn_beta
  docker_check_requirements || return 1
  docker_detect_dir || return 1
  # No update as portas já estão no .env.docker — apenas lê para exibir no success
  docker_backend_port=$(grep "^BACKEND_PORT=" "${DOCKER_DIR}/.env.docker" 2>/dev/null | cut -d= -f2 || echo "7563")
  docker_frontend_port=$(grep "^FRONTEND_PORT=" "${DOCKER_DIR}/.env.docker" 2>/dev/null | cut -d= -f2 || echo "7564")
  docker_frontnovo_port=$(grep "^FRONTNOVO_PORT=" "${DOCKER_DIR}/.env.docker" 2>/dev/null | cut -d= -f2 || echo "7565")
  docker_stop_containers
  docker_update_extract || return 1
  docker_copy_compose
  docker_compose_rebuild
  docker_update_success
}

#######################################
# Submenu: Instalar ou Atualizar Docker
# Arguments:
#   None
#######################################
docker_install_or_update() {
  print_banner
  printf "${WHITE}  💻 Docker (Beta) — ZPRO em containers${NC}\n\n"
  printf "${LINE}\n"
  printf "  ${GREEN}[1]${NC}  Instalar Docker\n"
  printf "       ${DIM}↳ Extrai zip, configura .env.docker, nginx, SSL e sobe containers${NC}\n\n"
  printf "  ${YELLOW}[2]${NC}  Atualizar Docker\n"
  printf "       ${DIM}↳ Para containers, extrai update.zip, rebuilda imagens e reinicia${NC}\n"
  printf "${LINE}\n"
  printf "  ${DIM}[0]${NC}  Voltar\n\n"
  read -p "  Opção > " _dk_option

  case "${_dk_option}" in
    1)
      install_docker_zpro
      ;;
    2)
      update_docker_zpro
      ;;
    0)
      inquiry_options
      ;;
    *)
      docker_install_or_update
      ;;
  esac
}
