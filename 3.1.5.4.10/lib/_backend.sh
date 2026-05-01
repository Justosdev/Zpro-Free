#!/bin/bash
# 
# functions for setting up app backend

#######################################
# creates docker db
# Arguments:
#   None
#######################################
backend_db_create() {
  step_header "🗄️ " "Criando containers de infraestrutura" \
    "Sobe 3 containers Docker essenciais para o funcionamento do ZPRO:"
  printf "  ${DIM}• postgresql  — banco de dados relacional na porta 5433 (dados em /data)${NC}\n"
  printf "  ${DIM}• redis-zpro  — cache em memória na porta 6379 (filas, sessões, pub/sub)${NC}\n"
  printf "  ${DIM}• portainer   — interface de gerenciamento Docker nas portas 9000 e 9443${NC}\n\n"

  start_spinner "Criando containers PostgreSQL, Redis e Portainer..."
  sudo su - root <<EOF
  usermod -aG docker deployzdg

  mkdir -p /data
  chown -R 999:999 /data

  docker run --name postgresql \
                -e POSTGRES_PASSWORD=${pg_pass} \
                -e TZ="America/Sao_Paulo" \
                -e PGDATA=/var/lib/postgresql/datazpro \
                -p 127.0.0.1:5433:5432 \
                --restart=always \
                -v /data:/var/lib/postgresql/datazpro \
                -d postgres \
                -c shared_buffers=256MB \
                -c work_mem=16MB \
                -c effective_cache_size=1GB \
                -c maintenance_work_mem=128MB \
                -c max_connections=200

  docker run --name redis-zpro \
                -e TZ="America/Sao_Paulo" \
                -p 6379:6379 \
                --restart=always \
                -d redis:latest redis-server \
                --appendonly yes \
                --appendfsync everysec \
                --no-appendfsync-on-rewrite yes \
                --maxmemory 2gb \
                --maxmemory-policy noeviction \
                --lazyfree-lazy-eviction yes \
                --lazyfree-lazy-expire yes \
                --lazyfree-lazy-server-del yes \
                --save "900 1" \
                --save "3600 1000" \
                --requirepass "${redis_pass}"
  
  docker run -d --name portainer \
                -p 9000:9000 -p 9443:9443 \
                --restart=always \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v portainer_data:/data \
                -e PORTAINER_PASSWORD=${portainer_pass} \
                portainer/portainer-ce
EOF
  stop_spinner "Containers criados: postgresql, redis-zpro, portainer."
  sleep 1
}

#######################################
# install_chrome
# Arguments:
#   None
#######################################
backend_chrome_install() {
  step_header "🌐" "Instalando Google Chrome" \
    "Chrome estável é usado pelo Puppeteer para geração de PDFs de conversas."
  printf "  ${DIM}Roda em modo headless (sem tela) — especificado no .env como CHROME_BIN.${NC}\n\n"

  start_spinner "Adicionando repositório Google e instalando google-chrome-stable..."
  sudo su - root <<EOF
  sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
  apt-get update
  apt-get install -y google-chrome-stable
EOF
  stop_spinner "Google Chrome instalado."
  sleep 1
}

#######################################
# sets environment variable for backend.
# Arguments:
#   None
#######################################
backend_set_env() {
  step_header "⚙️ " "Configurando variáveis de ambiente do backend" \
    "Gera senhas aleatórias e cria o arquivo .env em /home/deployzdg/zpro.io/backend/.env"
  printf "  ${DIM}Contém: URLs, credenciais do PostgreSQL, Redis, JWT secrets e limites de uso.${NC}\n\n"

  sleep 1
  
  # Remover arquivo de credenciais existente se houver
  if [ -f "${PROJECT_ROOT}"/db_credentials ]; then
    rm -f "${PROJECT_ROOT}"/db_credentials
  fi
  
  # Gerar senhas aleatórias
  pg_pass=$(openssl rand -base64 32)
  redis_pass=$(openssl rand -base64 32)
  portainer_pass=$(openssl rand -base64 12)

  # Salvar as senhas em um arquivo para reutilização
  cat << EOF > "${PROJECT_ROOT}"/db_credentials
pg_pass=${pg_pass}
redis_pass=${redis_pass}
portainer_pass=${portainer_pass}
deploy_password=${deploy_password}
EOF

  # ensure idempotency
  backend_url=$(echo "${backend_url/https:\/\/}")
  backend_url=${backend_url%%/*}
  backend_url=https://$backend_url

  # ensure idempotency
  frontend_url=$(echo "${frontend_url/https:\/\/}")
  frontend_url=${frontend_url%%/*}
  frontend_url=https://$frontend_url
  
  # Generate dynamic secrets
  jwt_secret=$(openssl rand -base64 32)
  jwt_refresh_secret=$(openssl rand -base64 32)

sudo su - deployzdg << EOF
  cat <<[-]EOF > /home/deployzdg/zpro.io/backend/.env
NODE_ENV=
BACKEND_URL=${backend_url}
FRONTEND_URL=${frontend_url}
ADMIN_DOMAIN=zpro.io

PROXY_PORT=443
PORT=3000

# conexão com o banco de dados (porta 5433 para não usar a padrão 5432)
DB_DIALECT=postgres
DB_PORT=5433
DB_TIMEZONE=-03:00
POSTGRES_HOST=localhost
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${pg_pass}
POSTGRES_DB=postgres

# Chaves para criptografia do token jwt
JWT_SECRET=${jwt_secret}
JWT_REFRESH_SECRET=${jwt_refresh_secret}

# Dados de conexão com o REDIS
#IO_REDIS_SERVER=localhost
#IO_REDIS_PASSWORD=${redis_pass}
#IO_REDIS_PORT=6379
#IO_REDIS_DB_SESSION=2

#CHROME_BIN=/usr/bin/google-chrome
CHROME_BIN=/usr/bin/google-chrome-stable

# tempo para randomização da mensagem de horário de funcionamento
MIN_SLEEP_BUSINESS_HOURS=1000
MAX_SLEEP_BUSINESS_HOURS=2000

# tempo para randomização das mensagens do bot
MIN_SLEEP_AUTO_REPLY=400
MAX_SLEEP_AUTO_REPLY=600

# tempo para randomização das mensagens gerais
MIN_SLEEP_INTERVAL=200
MAX_SLEEP_INTERVAL=500

# dados do RabbitMQ / Para não utilizar, basta comentar a var AMQP_URL
# RABBITMQ_DEFAULT_USER=zpro
# RABBITMQ_DEFAULT_PASS=${rabbit_pass}
# AMQP_URL='amqp://zpro:${rabbit_pass}@localhost:5672?connection_attempts=5&retry_delay=5'

# api oficial (integração em desenvolvimento)
API_URL_360=https://waba-sandbox.360dialog.io

# usado para mosrar opções não disponíveis normalmente.
ADMIN_DOMAIN=zpro.io

# Dados para utilização do canal do facebook
FACEBOOK_APP_ID=3237415623048660
FACEBOOK_APP_SECRET_KEY=3266214132b8c98ac59f3e957a5efeaaa13500

# Limitar Uso do zpro Usuario e Conexões
USER_LIMIT=99
CONNECTIONS_LIMIT=99
[-]EOF
EOF

  sleep 2
}

#######################################
# installs node.js dependencies
# Arguments:
#   None
#######################################
backend_node_dependencies() {
  step_header "📦" "Instalando dependências do backend" \
    "Executa npm install --force em /home/deployzdg/zpro.io/backend."
  printf "  ${DIM}Instala todos os pacotes do package.json: Express, Sequelize, Baileys,${NC}\n"
  printf "  ${DIM}Socket.IO, Bull, Puppeteer e demais dependências. Pode levar 3-5 minutos.${NC}\n\n"

  start_spinner "Instalando pacotes npm do backend (pode demorar alguns minutos)..."
  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  npm install --force
EOF
  stop_spinner "Dependências do backend instaladas."
  sleep 1
}

#######################################
# compiles backend code
# Arguments:
#   None
#######################################
backend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  npm run build
EOF

  sleep 2
}

#######################################
# updates frontend code
# Arguments:
#   None
#######################################
backend_update() {
  print_banner
  printf "${WHITE} 💻 Atualizando o backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  pm2 stop all
  npm r whatsapp-web.js
  npm i whatsapp-web.js
  pm2 restart all
EOF

  sleep 2
}

#######################################
# runs db migrate
# Arguments:
#   None
#######################################
backend_db_migrate() {
  step_header "🗄️ " "Executando migrations do banco de dados" \
    "npx sequelize db:migrate — cria e atualiza as tabelas no PostgreSQL."
  printf "  ${DIM}As migrations definem o schema completo: tenants, usuários, tickets, contatos,${NC}\n"
  printf "  ${DIM}mensagens, sessões WhatsApp, filas, configurações e demais entidades.${NC}\n\n"

  start_spinner "Aplicando migrations no PostgreSQL (porta 5433)..."
  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  npx sequelize db:migrate
EOF
  stop_spinner "Migrations aplicadas. Schema do banco de dados criado."
  sleep 1
}

#######################################
# runs db seed
# Arguments:
#   None
#######################################
backend_db_seed() {
  step_header "🌱" "Populando banco de dados (seeds)" \
    "npx sequelize db:seed:all — insere os dados iniciais obrigatórios no banco."
  printf "  ${DIM}Seeds incluem: superadmin (superadmin@zpro.io), admin padrão (admin@zpro.io),${NC}\n"
  printf "  ${DIM}perfis de acesso, planos, configurações do sistema e tenant inicial.${NC}\n\n"

  start_spinner "Inserindo dados iniciais no banco (superadmin, admin, configurações)..."
  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  npx sequelize db:seed:all
EOF
  stop_spinner "Seeds aplicados. Dados iniciais inseridos no banco."
  sleep 1
}

#######################################
# starts backend using pm2 in 
# production mode.
# Arguments:
#   None
#######################################
backend_start_pm2() {
  step_header "🚀" "Iniciando backend com PM2" \
    "Inicia o servidor Node.js em produção com PM2."
  printf "  ${DIM}Processo: zpro-backend | Arquivo: dist/server.js | Heap: 2048 MB${NC}\n"
  printf "  ${DIM}PM2 mantém o processo ativo, reinicia em caso de falha e salva a lista de processos.${NC}\n\n"

  start_spinner "Iniciando zpro-backend com 2GB de heap..."
  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  pm2 start dist/server.js --name zpro-backend --node-args="--max-old-space-size=2048"
  pm2 save
EOF
  stop_spinner "Backend iniciado. Processo zpro-backend ativo no PM2."
  sleep 1
}

#######################################
# installs node
# Arguments:
#   None
#######################################
backend_bd_update() {
  step_header "🗄️ " "Corrigindo permissões do PostgreSQL" \
    "Garante que o usuário 'postgres' dentro do container seja dono dos arquivos de dados."
  printf "  ${DIM}Necessário quando o diretório /data é criado pelo root e depois montado no container.${NC}\n\n"

  start_spinner "Verificando e corrigindo permissões em /var/lib/postgresql/data..."
  sudo su - root <<EOF
  if docker ps -q -f name=postgresql; then
    docker exec -u root postgresql bash -c "chown -R postgres:postgres /var/lib/postgresql/data"
  else
    echo "Container postgresql não está em execução — pulando."
  fi
EOF
  stop_spinner "Permissões do PostgreSQL verificadas."
  sleep 1
}

#######################################
# updates frontend code
# Arguments:
#   None
#######################################
backend_nginx_setup() {
  step_header "🌐" "Configurando nginx para o backend" \
    "Cria /etc/nginx/sites-available/zpro-backend e ativa o vhost."
  printf "  ${DIM}O nginx recebe requisições HTTPS no domínio ${backend_url} e encaminha${NC}\n"
  printf "  ${DIM}para o backend Node.js rodando em http://127.0.0.1:3000.${NC}\n\n"

  sleep 1

  backend_hostname=$(echo "${backend_url/https:\/\/}")

sudo su - root << EOF

cat > /etc/nginx/sites-available/zpro-backend << 'END'
server {
  server_name $backend_hostname;

  location / {
    proxy_pass http://127.0.0.1:3000;
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

ln -s /etc/nginx/sites-available/zpro-backend /etc/nginx/sites-enabled
EOF

  sleep 2
}

#######################################
# reinicia o Portainer
# Arguments:
#   None
#######################################
portainer_restart() {
  print_banner
  printf "${WHITE} 💻 Reiniciando o Portainer...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  docker restart portainer
EOF

  sleep 2
}

#######################################
# remove o Portainer e seus volumes
# Arguments:
#   None
#######################################
portainer_remove() {
  print_banner
  printf "${WHITE} 💻 Removendo o Portainer e seus volumes...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  docker stop portainer
  docker rm portainer
  docker volume rm portainer_data
EOF

  sleep 2
}

#######################################
# recria o Portainer
# Arguments:
#   None
#######################################
portainer_recreate() {
  print_banner
  printf "${WHITE} 💻 Recriando o Portainer...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  docker run -d --name portainer \
                -p 9000:9000 -p 9443:9443 \
                --restart=always \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v portainer_data:/data \
                -e PORTAINER_PASSWORD=${portainer_pass} \
                portainer/portainer-ce
EOF

  sleep 2

  # Obter IP da máquina
  IP=$(hostname -I | awk '{print $1}')

  print_banner
  printf "${GREEN} ✅ Portainer recriado com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 URLs de acesso:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Interface Web: http://${IP}:9000"
  printf "\n"
  printf "  • Interface Segura: https://${IP}:9443"
  printf "\n"
  printf "  • Senha: ${portainer_pass}"
  printf "\n\n"
  printf "${YELLOW} ⚠️  Lembre-se de configurar o firewall para permitir acesso a estas portas se necessário${NC}"
  printf "\n\n"
}

#######################################
# Instala e configura Prometheus
# Arguments:
#   None
#######################################
setup_prometheus() {
  print_banner
  printf "${WHITE} 💻 Instalando e configurando Prometheus...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Remover containers existentes se houver
  docker stop prometheus node-exporter || true
  docker rm prometheus node-exporter || true

  # Criar diretório para dados do Prometheus
  mkdir -p /data/prometheus
  chown -R 65534:65534 /data/prometheus
  chmod -R 777 /data/prometheus

  # Criar arquivo de configuração
  cat > /data/prometheus/prometheus.yml << 'END'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
  - job_name: 'zpro'
    static_configs:
      - targets: ['zpro-backend:3000']
END

  # Iniciar Prometheus
  docker run -d --name prometheus \
    -p 9090:9090 \
    -v /data/prometheus:/prometheus \
    -v /data/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    --user 65534:65534 \
    --restart=always \
    prom/prometheus \
    --storage.tsdb.path=/prometheus \
    --web.console.libraries=/usr/share/prometheus/console_libraries \
    --web.console.templates=/usr/share/prometheus/consoles

  # Iniciar Node Exporter
  docker run -d --name node-exporter \
    -p 9100:9100 \
    --restart=always \
    prom/node-exporter
EOF

  sleep 2

  # Obter IP da máquina
  IP=$(hostname -I | awk '{print $1}')

  print_banner
  printf "${GREEN} ✅ Prometheus e Node Exporter instalados com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 URLs de acesso:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Prometheus: http://${IP}:9090"
  printf "\n"
  printf "  • Node Exporter: http://${IP}:9100"
  printf "\n\n"
  printf "${YELLOW} ⚠️  Lembre-se de configurar o firewall para permitir acesso a estas portas se necessário${NC}"
  printf "\n\n"
}

#######################################
# Instala e configura Grafana
# Arguments:
#   None
#######################################
setup_grafana() {
  print_banner
  printf "${WHITE} 💻 Instalando e configurando Grafana...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Remover container existente se houver
  docker stop grafana || true
  docker rm grafana || true

  # Criar diretório para dados do Grafana
  mkdir -p /data/grafana
  chown -R 472:472 /data/grafana
  chmod -R 777 /data/grafana

  # Iniciar Grafana
  docker run -d --name grafana \
    -p 3022:3000 \
    -v /data/grafana:/var/lib/grafana \
    --user 472:472 \
    --restart=always \
    grafana/grafana

  # Aguardar Grafana iniciar
  sleep 10

  # Configurar datasource do Prometheus
  curl -X POST "http://localhost:3022/api/datasources" \
    -H "Content-Type: application/json" \
    -u admin:admin \
    -d '{
      "name":"Prometheus",
      "type":"prometheus",
      "url":"http://prometheus:9090",
      "access":"proxy",
      "basicAuth":false
    }'
EOF

  sleep 2

  # Obter IP da máquina
  IP=$(hostname -I | awk '{print $1}')

  print_banner
  printf "${GREEN} ✅ Grafana instalado com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 URLs de acesso:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Grafana: http://${IP}:3022"
  printf "\n"
  printf "  • Credenciais padrão: admin/admin"
  printf "\n\n"
  printf "${YELLOW} ⚠️  Lembre-se de alterar a senha padrão após o primeiro login${NC}"
  printf "\n\n"
}

#######################################
# Configura backup personalizado
# Arguments:
#   None
#######################################
setup_backup() {
  print_banner
  printf "${WHITE} 💻 Configurando backup personalizado...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Criar diretório para backups
  mkdir -p /backup/zpro
  chown -R root:root /backup/zpro

  # Criar script de backup
  cat > /usr/local/bin/zpro-backup.sh << 'END'
#!/bin/bash
BACKUP_DIR="/backup/zpro"
DATE=\$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/zpro/backup.log"

# Função para registrar logs
log_message() {
  echo "[\$(date +"%Y-%m-%d %H:%M:%S")] \$1" >> \$LOG_FILE
}

# Função para extrair configurações do .env
get_db_config() {
  local env_file="\$1"
  local config=()
  
  if [ -f "\$env_file" ]; then
    config[0]=\$(grep "POSTGRES_USER=" "\$env_file" | cut -d'=' -f2)
    config[1]=\$(grep "POSTGRES_PASSWORD=" "\$env_file" | cut -d'=' -f2)
    config[2]=\$(grep "POSTGRES_DB=" "\$env_file" | cut -d'=' -f2)
    config[3]=\$(grep "POSTGRES_HOST=" "\$env_file" | cut -d'=' -f2)
    config[4]=\$(grep "DB_PORT=" "\$env_file" | cut -d'=' -f2)
  fi
  
  echo "\${config[@]}"
}

log_message "Iniciando backup"

# Encontrar todas as instâncias zpro.io dentro de /home/deployzdg
find /home/deployzdg -type d -name "zpro.io" | while read -r instance_path; do
  # Extrair nome da instância do caminho
  instance_name=\$(echo "\$instance_path" | grep -oP '(?<=/home/deployzdg/)[^/]+(?=/zpro\.io)')
  if [ -z "\$instance_name" ]; then
    instance_name="primeira_instancia"
  fi
  
  log_message "Backup da instância: \$instance_name"
  
  # Criar diretório para backup da instância
  instance_backup_dir="\$BACKUP_DIR/\$instance_name"
  mkdir -p "\$instance_backup_dir"
  
  # Backup dos arquivos da instância
  log_message "Fazendo backup dos arquivos"
  tar -czf "\$instance_backup_dir/files_\$DATE.tar.gz" "\$instance_path"
  
  # Verificar se existe arquivo .env no backend
  env_file="\$instance_path/backend/.env"
  if [ -f "\$env_file" ]; then
    # Extrair configurações do banco
    read -r -a db_config <<< "\$(get_db_config "\$env_file")"
    
    if [ \${#db_config[@]} -ge 5 ]; then
      # Fazer backup do banco de dados
      log_message "Fazendo backup do banco de dados"
      PGPASSWORD="\${db_config[1]}" pg_dump -h "\${db_config[3]}" -p "\${db_config[4]}" -U "\${db_config[0]}" "\${db_config[2]}" > "\$instance_backup_dir/db_\$DATE.sql"
    fi
  fi
  
  # Manter apenas os últimos 7 backups para esta instância
  log_message "Removendo backups antigos"
  find "\$instance_backup_dir" -type f -mtime +7 -delete
done

# Backup do Prometheus e Grafana
if [ -d "/data/prometheus" ]; then
  log_message "Fazendo backup do Prometheus"
  tar -czf "\$BACKUP_DIR/prometheus_\$DATE.tar.gz" /data/prometheus
fi

if [ -d "/data/grafana" ]; then
  log_message "Fazendo backup do Grafana"
  tar -czf "\$BACKUP_DIR/grafana_\$DATE.tar.gz" /data/grafana
fi

# Manter apenas os últimos 7 backups dos serviços
find "\$BACKUP_DIR" -type f -name "prometheus_*.tar.gz" -mtime +7 -delete
find "\$BACKUP_DIR" -type f -name "grafana_*.tar.gz" -mtime +7 -delete

log_message "Backup concluído com sucesso"
END

  chmod +x /usr/local/bin/zpro-backup.sh
  chown root:root /usr/local/bin/zpro-backup.sh

  # Criar diretório para logs
  mkdir -p /var/log/zpro
  chown -R root:root /var/log/zpro

  # Adicionar ao crontab do root
  echo "0 2 * * * /usr/local/bin/zpro-backup.sh" | crontab -
EOF

  sleep 2

  print_banner
  printf "${GREEN} ✅ Backup personalizado configurado com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 Informações do Backup:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Diretório de backup: /backup/zpro"
  printf "\n"
  printf "  • Logs: /var/log/zpro/backup.log"
  printf "\n"
  printf "  • Agendamento: Todos os dias às 2h da manhã"
  printf "\n"
  printf "  • Retenção: Últimos 7 dias"
  printf "\n"
  printf "  • O backup inclui:${NC}"
  printf "\n"
  printf "  • Todas as instâncias ZPRO encontradas em /home/deployzdg"
  printf "\n"
  printf "  • Bancos de dados de cada instância"
  printf "\n"
  printf "  • Dados do Prometheus e Grafana"
  printf "\n\n"
  printf "${WHITE} 📊 Comandos úteis:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Ver logs em tempo real: tail -f /var/log/zpro/backup.log"
  printf "\n"
  printf "  • Listar backups: ls -lh /backup/zpro"
  printf "\n"
  printf "  • Ver backups de uma instância: ls -lh /backup/zpro/NOME_DA_INSTANCIA"
  printf "\n"
  printf "  • Executar backup manualmente: sudo /usr/local/bin/zpro-backup.sh"
  printf "\n\n"
  printf "${YELLOW} ⚠️  Os backups são mantidos por 7 dias e são executados automaticamente${NC}"
  printf "\n\n"
}

#######################################
# Configura Rate Limiting
# Arguments:
#   None
#######################################
setup_rate_limiting() {
  print_banner
  printf "${WHITE} 💻 Configurando Rate Limiting...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Instalar fail2ban
  apt-get install -y fail2ban

  # Criar diretório para logs do rate limiting
  mkdir -p /var/log/nginx/rate-limiting
  chown -R www-data:www-data /var/log/nginx/rate-limiting

  # Configurar rate limiting no nginx
  cat > /etc/nginx/conf.d/rate-limiting.conf << 'END'
# Configuração de zonas para rate limiting
limit_req_zone \$binary_remote_addr zone=one:10m rate=1r/s;
limit_conn_zone \$binary_remote_addr zone=addr:10m;

# Configuração de logging
log_format rate_limiting '\$remote_addr - \$remote_user [\$time_local] '
                        '"\$request" \$status \$body_bytes_sent '
                        '"\$http_referer" "\$http_user_agent" '
                        'Rate-Limited: \$limit_req_status '
                        'Connections: \$limit_conn_status';

access_log /var/log/nginx/rate-limiting/access.log rate_limiting;

server {
    location / {
        # Limitar requisições
        limit_req zone=one burst=10 nodelay;
        # Limitar conexões
        limit_conn addr 10;
        
        # Configurações adicionais
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_cache_bypass \$http_upgrade;
    }
}
END

  # Reiniciar nginx
  systemctl restart nginx
EOF

  sleep 2

  print_banner
  printf "${GREEN} ✅ Rate Limiting configurado com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 Informações do Rate Limiting:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Logs: /var/log/nginx/rate-limiting/access.log"
  printf "\n"
  printf "  • Configuração: /etc/nginx/conf.d/rate-limiting.conf"
  printf "\n"
  printf "  • Limites configurados:${NC}"
  printf "\n"
  printf "  • Requisições: 1 por segundo (burst de 10)"
  printf "\n"
  printf "  • Conexões simultâneas: 10 por IP"
  printf "\n\n"
  printf "${WHITE} 📊 Comandos úteis:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Ver logs em tempo real: tail -f /var/log/nginx/rate-limiting/access.log"
  printf "\n"
  printf "  • Ver status do nginx: systemctl status nginx"
  printf "\n"
  printf "  • Ver configuração: cat /etc/nginx/conf.d/rate-limiting.conf"
  printf "\n\n"
  printf "${YELLOW} ⚠️  IPs que excederem os limites serão temporariamente bloqueados${NC}"
  printf "\n\n"
}

#######################################
# Configura Fail2ban
# Arguments:
#   None
#######################################
setup_fail2ban() {
  print_banner
  printf "${WHITE} 💻 Configurando Fail2ban...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Configurar fail2ban
  cat > /etc/fail2ban/jail.local << 'END'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 3
bantime = 3600

[nginx-dos]
enabled = true
port = http,https
filter = nginx-dos
logpath = /var/log/nginx/access.log
maxretry = 3
bantime = 3600
END

  # Reiniciar fail2ban
  systemctl restart fail2ban

  # Criar diretório para logs do fail2ban
  mkdir -p /var/log/fail2ban
  chown -R root:root /var/log/fail2ban
EOF

  sleep 2

  print_banner
  printf "${GREEN} ✅ Fail2ban configurado com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 Informações do Fail2ban:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Logs: /var/log/fail2ban/fail2ban.log"
  printf "\n"
  printf "  • Configuração: /etc/fail2ban/jail.local"
  printf "\n"
  printf "  • Monitoramento:${NC}"
  printf "\n"
  printf "  • SSH - Bloqueia após 3 tentativas falhas"
  printf "\n"
  printf "  • Nginx Auth - Protege contra tentativas de login"
  printf "\n"
  printf "  • Nginx Bot - Bloqueia bots maliciosos"
  printf "\n"
  printf "  • Nginx DoS - Protege contra ataques DoS"
  printf "\n\n"
  printf "${WHITE} 📊 Comandos úteis:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Ver status: sudo fail2ban-client status"
  printf "\n"
  printf "  • Ver logs em tempo real: tail -f /var/log/fail2ban/fail2ban.log"
  printf "\n"
  printf "  • Ver IPs banidos: sudo fail2ban-client status sshd"
  printf "\n"
  printf "  • Desbanir IP: sudo fail2ban-client set sshd unbanip IP_ADDRESS"
  printf "\n\n"
  printf "${YELLOW} ⚠️  O banimento padrão é de 1 hora após 3 tentativas falhas${NC}"
  printf "\n\n"
}

#######################################
# Configura Health Check
# Arguments:
#   None
#######################################
setup_health_check() {
  print_banner
  printf "${WHITE} 💻 Configurando Health Check...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Criar diretório para logs do health check
  mkdir -p /var/log/zpro
  chown -R deployzdg:deployzdg /var/log/zpro

  # Criar script de health check
  cat > /usr/local/bin/zpro-health-check.sh << 'END'
#!/bin/bash

LOG_FILE="/var/log/zpro/health-check.log"
DATE=\$(date +"%Y-%m-%d %H:%M:%S")

# Função para registrar logs
log_message() {
  echo "[\$DATE] \$1" >> \$LOG_FILE
}

# Verificar status do PM2
if ! sudo -u deployzdg pm2 list | grep -q "online"; then
  log_message "PM2 não está rodando"
  exit 1
else
  log_message "PM2 está rodando normalmente"
fi

# Verificar status do PostgreSQL
if ! docker ps | grep -q "postgresql"; then
  log_message "PostgreSQL não está rodando"
  exit 1
else
  log_message "PostgreSQL está rodando normalmente"
fi

# Verificar status do Redis
if ! docker ps | grep -q "redis-zpro"; then
  log_message "Redis não está rodando"
  exit 1
else
  log_message "Redis está rodando normalmente"
fi

# Verificar uso de disco
DISK_USAGE=\$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ \$DISK_USAGE -gt 90 ]; then
  log_message "Uso de disco acima de 90%"
  exit 1
else
  log_message "Uso de disco: \$DISK_USAGE%"
fi

# Verificar uso de memória
MEM_USAGE=\$(free | awk '/Mem:/ {print int(\$3/\$2 * 100)}')
if [ \$MEM_USAGE -gt 90 ]; then
  log_message "Uso de memória acima de 90%"
  exit 1
else
  log_message "Uso de memória: \$MEM_USAGE%"
fi

log_message "Health check concluído com sucesso"
exit 0
END

  chmod +x /usr/local/bin/zpro-health-check.sh
  chown deployzdg:deployzdg /usr/local/bin/zpro-health-check.sh

  # Adicionar ao crontab do usuário deployzdg
  sudo -u deployzdg bash -c 'echo "*/5 * * * * /usr/local/bin/zpro-health-check.sh" | crontab -'
EOF

  sleep 2

  print_banner
  printf "${GREEN} ✅ Health Check configurado com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 Informações do Health Check:${GRAY_LIGHT}"
  printf "\n"
  printf "  • Logs: /var/log/zpro/health-check.log"
  printf "\n"
  printf "  • Verificação: A cada 5 minutos"
  printf "\n"
  printf "  • Monitora:${NC}"
  printf "\n"
  printf "  • Status do PM2"
  printf "\n"
  printf "  • Status do PostgreSQL"
  printf "\n"
  printf "  • Status do Redis"
  printf "\n"
  printf "  • Uso de disco"
  printf "\n"
  printf "  • Uso de memória"
  printf "\n\n"
  printf "${YELLOW} ⚠️  Para verificar os logs em tempo real, use: tail -f /var/log/zpro/health-check.log${NC}"
  printf "\n\n"
}

#######################################
# Configura Firewall
# Arguments:
#   None
#######################################
setup_firewall() {
  print_banner
  printf "${WHITE} 💻 Configurando Firewall...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Instalar UFW se não estiver instalado
  if ! command -v ufw &> /dev/null; then
    apt-get update
    apt-get install -y ufw
  fi

  # Resetar configurações do UFW
  ufw --force reset

  # Configurar regras padrão
  ufw default deny incoming
  ufw default allow outgoing

  # Permitir portas essenciais
  ufw allow 22/tcp    # SSH
  ufw allow 80/tcp    # HTTP
  ufw allow 81/tcp    # HTTP Alternativo
  ufw allow 443/tcp   # HTTPS
  ufw allow 9000/tcp  # Porta para serviços
  ufw allow 9007/tcp  # Portainer
  ufw allow 3011/tcp  # Grafana
  ufw allow 3022/tcp  # Grafana
  ufw allow 9090/tcp  # Prometheus

  # Habilitar UFW
  ufw --force enable

  # Mostrar status
  ufw status numbered
EOF

  sleep 2

  print_banner
  printf "${GREEN} ✅ Firewall configurado com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  printf "${WHITE} 📊 Portas configuradas:${GRAY_LIGHT}"
  printf "\n"
  printf "  • 22/tcp   - SSH"
  printf "\n"
  printf "  • 80/tcp   - HTTP"
  printf "\n"
  printf "  • 81/tcp   - HTTP Alternativo"
  printf "\n"
  printf "  • 443/tcp  - HTTPS"
  printf "\n"
  printf "  • 9000/tcp - Serviços"
  printf "\n"
  printf "  • 9007/tcp - Portainer"
  printf "\n"
  printf "  • 3011/tcp - Grafana"
  printf "\n"
  printf "  • 3022/tcp - Grafana"
  printf "\n"
  printf "  • 9090/tcp - Prometheus"
  printf "\n\n"
  printf "${YELLOW} ⚠️  Todas as outras portas estão bloqueadas por padrão${NC}"
  printf "\n\n"
}

#######################################
# Configurações Avançadas
# Arguments:
#   None
#######################################
advanced_settings() {
  print_banner
  printf "${WHITE} 💻 O que você deseja configurar?${GRAY_LIGHT}"
  printf "\n\n"
  printf "  [1] Configurar backup personalizado\n"
  printf "  [2] Configurar Rate Limiting\n"
  printf "  [3] Configurar Fail2ban\n"
  printf "  [4] Configurar Health Check\n"
  printf "  [5] Configurar Firewall\n"
  printf "  [6] Configurar tudo\n"
  printf "\n\n"
  read -p "> " advanced_option

  case "${advanced_option}" in
    1) setup_backup ;;
    2) setup_rate_limiting ;;
    3) setup_fail2ban ;;
    4) setup_health_check ;;
    5) setup_firewall ;;
    6)
      setup_backup
      setup_rate_limiting
      setup_fail2ban
      setup_health_check
      setup_firewall
      ;;
    *) exit ;;
  esac
}

#######################################
# Altera subdomínio da ZPRO
# Arguments:
#   None
#######################################
change_subdomain() {
  print_banner
  printf "${WHITE} 💻 Alterando domínios da ZPRO...${GRAY_LIGHT}"
  printf "\n\n"

  # Mapear instâncias existentes
  instances=()
  while IFS= read -r instance; do
    instance_name=$(echo "$instance" | grep -oP '(?<=/home/deployzdg/)[^/]+(?=/zpro\.io)')
    if [ -z "$instance_name" ]; then
      instance_name="primeira_instancia"
    fi
    instances+=("$instance_name")
  done < <(find /home/deployzdg -type d -name "zpro.io")

  if [ ${#instances[@]} -eq 0 ]; then
    printf "${RED} ❌ Nenhuma instância ZPRO encontrada!${NC}\n\n"
    return 1
  fi

  # Mostrar instâncias disponíveis
  printf "${WHITE} 📊 Instâncias encontradas:${GRAY_LIGHT}\n\n"
  for i in "${!instances[@]}"; do
    printf "  [$(($i+1))] ${instances[$i]}\n"
  done
  printf "\n"

  # Perguntar qual instância alterar
  read -p "> Digite o número da instância que deseja alterar: " instance_number
  if [ "$instance_number" -lt 1 ] || [ "$instance_number" -gt ${#instances[@]} ]; then
    printf "${RED} ❌ Opção inválida!${NC}\n\n"
    return 1
  fi

  selected_instance=${instances[$(($instance_number-1))]}
  
  # Definir o caminho correto da instância
  if [ "$selected_instance" = "primeira_instancia" ]; then
    instance_path="/home/deployzdg/zpro.io"
  else
    instance_path="/home/deployzdg/$selected_instance/zpro.io"
  fi

  # Buscar portas dinamicamente
  frontend_port=$(grep -oP 'app\.listen\(\K[0-9]+' "$instance_path/frontend/server.js")
  backend_port=$(grep -oP '^PORT=\K[0-9]+' "$instance_path/backend/.env")

  if [ -z "$frontend_port" ]; then
    printf "${RED} ❌ Não foi possível encontrar a porta do frontend!${NC}\n\n"
    return 1
  fi

  if [ -z "$backend_port" ]; then
    printf "${RED} ❌ Não foi possível encontrar a porta do backend!${NC}\n\n"
    return 1
  fi

  # Perguntar novos domínios
  read -p "> Digite o novo domínio do backend (ex: api.novo.zpro.io): " new_backend_domain
  if [ -z "$new_backend_domain" ]; then
    printf "${RED} ❌ Domínio do backend inválido!${NC}\n\n"
    return 1
  fi

  read -p "> Digite o novo domínio do frontend (ex: novo.zpro.io): " new_frontend_domain
  if [ -z "$new_frontend_domain" ]; then
    printf "${RED} ❌ Domínio do frontend inválido!${NC}\n\n"
    return 1
  fi

  # Extrair domínio base
  base_domain=$(echo "$new_frontend_domain" | cut -d'.' -f2-)

  # Alterar .env do backend
  if [ -f "$instance_path/backend/.env" ]; then
    sed -i "s|BACKEND_URL=.*|BACKEND_URL=https://$new_backend_domain|" "$instance_path/backend/.env"
    sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$new_frontend_domain|" "$instance_path/backend/.env"
  fi

  # Alterar .env do frontend
  if [ -f "$instance_path/frontend/.env" ]; then
    sed -i "s|URL_API=.*|URL_API=https://$new_backend_domain|" "$instance_path/frontend/.env"
  fi

  # Configurar nginx
  if [ "$selected_instance" = "primeira_instancia" ]; then
    backend_config="zpro-backend"
    frontend_config="zpro-frontend"
  else
    backend_config="${selected_instance}-zpro-backend"
    frontend_config="${selected_instance}-zpro-frontend"
  fi

  # Remover configurações antigas do nginx
  rm -f "/etc/nginx/sites-available/$backend_config"
  rm -f "/etc/nginx/sites-available/$frontend_config"
  rm -f "/etc/nginx/sites-enabled/$backend_config"
  rm -f "/etc/nginx/sites-enabled/$frontend_config"

  # Configurar backend no nginx
  cat > "/etc/nginx/sites-available/$backend_config" << EOF
server {
  server_name $new_backend_domain;

  location / {
    proxy_pass http://127.0.0.1:$backend_port;
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
EOF

  # Configurar frontend no nginx
  cat > "/etc/nginx/sites-available/$frontend_config" << EOF
server {
  server_name $new_frontend_domain;

  location / {
    proxy_pass http://127.0.0.1:$frontend_port;
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
EOF

  # Ativar configurações do nginx
  ln -sf "/etc/nginx/sites-available/$backend_config" "/etc/nginx/sites-enabled/"
  ln -sf "/etc/nginx/sites-available/$frontend_config" "/etc/nginx/sites-enabled/"

  # Capturar email para o certbot
  read -p "> Digite o email para o certificado SSL: " ssl_email
  if [ -z "$ssl_email" ]; then
    printf "${RED} ❌ Email inválido!${NC}\n\n"
    return 1
  fi

  # Gerar certificados SSL
  certbot --nginx -d $new_backend_domain -d $new_frontend_domain --redirect --non-interactive --agree-tos --email $ssl_email

  # Verificar se o nginx está rodando
  if ! systemctl is-active --quiet nginx; then
    printf "${YELLOW} ⚠️  Nginx não está rodando, tentando iniciar...${NC}\n"
    systemctl start nginx
  fi

  # Verificar configuração do nginx
  if ! nginx -t; then
    printf "${RED} ❌ Erro na configuração do nginx! Verifique os logs.${NC}\n\n"
    return 1
  fi

  # Tentar reiniciar o nginx
  if ! systemctl restart nginx; then
    printf "${YELLOW} ⚠️  Erro ao reiniciar o nginx, tentando forçar reinicialização...${NC}\n"
    # Forçar parada de todos os processos nginx
    killall nginx 2>/dev/null || true
    # Remover arquivo PID se existir
    rm -f /run/nginx.pid
    # Tentar iniciar novamente
    if ! systemctl start nginx; then
      printf "${RED} ❌ Erro ao reiniciar o nginx após tentativa forçada! Verifique os logs.${NC}\n\n"
      return 1
    fi
  fi

  # Reconstruir frontend
  sudo -u deployzdg bash -c "cd $instance_path/frontend && npm run build"

  # Reiniciar serviços
  sudo -u deployzdg pm2 restart all

  print_banner
  printf "${GREEN} ✅ Domínios alterados com sucesso!${GRAY_LIGHT}\n\n"
  printf "${WHITE} 📊 Informações:${GRAY_LIGHT}\n"
  printf "  • Instância: $selected_instance\n"
  printf "  • Novo domínio do backend: $new_backend_domain (porta: $backend_port)\n"
  printf "  • Novo domínio do frontend: $new_frontend_domain (porta: $frontend_port)\n"
  printf "  • Configurações nginx: $backend_config e $frontend_config\n\n"
  printf "${YELLOW} ⚠️  Lembre-se de atualizar o DNS dos novos domínios para apontar para este servidor${NC}\n\n"
}

#######################################
# recria o Redis para uma instância específica
# Arguments:
#   None
#######################################
recreate_redis() {
  print_banner
  printf "${WHITE} 💻 Recriando Redis...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Mapear instâncias existentes
  instances=()
  while IFS= read -r instance; do
    instance_name=$(echo "$instance" | grep -oP '(?<=/home/deployzdg/)[^/]+(?=/zpro\.io)')
    if [ -z "$instance_name" ]; then
      instance_name="primeira_instancia"
    fi
    instances+=("$instance_name")
  done < <(find /home/deployzdg -type d -name "zpro.io")

  if [ ${#instances[@]} -eq 0 ]; then
    printf "${RED} ❌ Nenhuma instância ZPRO encontrada!${NC}\n\n"
    return 1
  fi

  # Mostrar instâncias disponíveis
  printf "${WHITE} 📊 Instâncias encontradas:${GRAY_LIGHT}\n\n"
  for i in "${!instances[@]}"; do
    printf "  [$(($i+1))] ${instances[$i]}\n"
  done
  printf "\n"

  # Perguntar qual instância atualizar
  read -p "> Digite o número da instância que deseja atualizar: " instance_number
  if [ "$instance_number" -lt 1 ] || [ "$instance_number" -gt ${#instances[@]} ]; then
    printf "${RED} ❌ Opção inválida!${NC}\n\n"
    return 1
  fi

  selected_instance=${instances[$(($instance_number-1))]}
  
  # Definir o caminho correto da instância
  if [ "$selected_instance" = "primeira_instancia" ]; then
    instance_path="/home/deployzdg/zpro.io"
    container_name="redis-zpro"
  else
    instance_path="/home/deployzdg/$selected_instance/zpro.io"
    container_name="${selected_instance}-redis-zpro"
  fi

  # Verificar se existe arquivo .env no backend
  env_file="$instance_path/backend/.env"
  if [ -f "$env_file" ]; then
    # Extrair configurações do Redis
    redis_port=$(grep "IO_REDIS_PORT=" "$env_file" | cut -d'=' -f2)
    redis_pass=$(grep "IO_REDIS_PASSWORD=" "$env_file" | sed 's/IO_REDIS_PASSWORD=//')
    
    if [ ! -z "$redis_port" ] && [ ! -z "$redis_pass" ]; then
      sudo su - root <<EOF
      # Parar e remover container existente se houver
      docker stop "$container_name" 2>/dev/null || true
      docker rm "$container_name" 2>/dev/null || true
      
      # Criar novo container Redis com a senha existente
      docker run --name "$container_name" \
        -e TZ="America/Sao_Paulo" \
        -p "${redis_port}:6379" \
        --restart=always \
        -d redis:latest redis-server \
        --appendonly yes \
        --appendfsync everysec \
        --no-appendfsync-on-rewrite yes \
        --maxmemory 2gb \
        --maxmemory-policy noeviction \
        --lazyfree-lazy-eviction yes \
        --lazyfree-lazy-expire yes \
        --lazyfree-lazy-server-del yes \
        --save "900 1" \
        --save "3600 1000" \
        --requirepass "${redis_pass}"
EOF
      printf "${GREEN} ✅ Redis recriado para a instância $selected_instance na porta $redis_port${NC}\n"
      printf "${YELLOW} ⚠️  Usando a senha existente do arquivo .env${NC}\n"
      
      # Reiniciar todos os processos PM2
      sudo -u deployzdg pm2 restart all
      printf "${GREEN} ✅ Todos os processos PM2 reiniciados${NC}\n"
    else
      printf "${YELLOW} ⚠️  Configurações do Redis não encontradas para a instância $selected_instance${NC}\n"
    fi
  else
    printf "${YELLOW} ⚠️  Arquivo .env não encontrado para a instância $selected_instance${NC}\n"
  fi

  sleep 2
}

#######################################
# Instala a interface do webchat
# Arguments:
#   None
#######################################
install_webchat() {
  print_banner
  printf "${WHITE} 💻 Instalando interface do webchat...${GRAY_LIGHT}"
  printf "\n\n"

  # Mapear instâncias existentes
  instances=()
  while IFS= read -r instance; do
    instance_name=$(echo "$instance" | grep -oP '(?<=/home/deployzdg/)[^/]+(?=/zpro\.io)')
    if [ -z "$instance_name" ]; then
      instance_name="primeira_instancia"
    fi
    instances+=("$instance_name")
  done < <(find /home/deployzdg -type d -name "zpro.io")

  if [ ${#instances[@]} -eq 0 ]; then
    printf "${RED} ❌ Nenhuma instância ZPRO encontrada!${NC}\n\n"
    return 1
  fi

  # Mostrar instâncias disponíveis
  printf "${WHITE} 📊 Instâncias encontradas:${GRAY_LIGHT}\n\n"
  for i in "${!instances[@]}"; do
    printf "  [$(($i+1))] ${instances[$i]}\n"
  done
  printf "\n"

  # Perguntar qual instância atualizar
  read -p "> Digite o número da instância que deseja instalar o webchat: " instance_number
  if [ "$instance_number" -lt 1 ] || [ "$instance_number" -gt ${#instances[@]} ]; then
    printf "${RED} ❌ Opção inválida!${NC}\n\n"
    return 1
  fi

  selected_instance=${instances[$(($instance_number-1))]}
  
  # Definir o caminho correto da instância
  if [ "$selected_instance" = "primeira_instancia" ]; then
    instance_path="/home/deployzdg/zpro.io"
    nginx_config="zpro-webchat"
  else
    instance_path="/home/deployzdg/$selected_instance/zpro.io"
    nginx_config="${selected_instance}-zpro-webchat"
  fi

  # Perguntar porta e URL do webchat
  read -p "> Digite a porta do webchat (ex: 3019): " webchat_port
  if [ -z "$webchat_port" ]; then
    printf "${RED} ❌ Porta inválida!${NC}\n\n"
    return 1
  fi

  read -p "> Digite a URL do webchat (ex: chat.seudominio.com): " webchat_url
  if [ -z "$webchat_url" ]; then
    printf "${RED} ❌ URL inválida!${NC}\n\n"
    return 1
  fi

  # Capturar email para o certbot
  read -p "> Digite o email para o certificado SSL: " ssl_email
  if [ -z "$ssl_email" ]; then
    printf "${RED} ❌ Email inválido!${NC}\n\n"
    return 1
  fi

  # Atualizar .env do backend
  env_file="$instance_path/backend/.env"
  if [ -f "$env_file" ]; then
    # Verificar se as variáveis já existem
    if grep -q "WSS_URL=" "$env_file"; then
      sed -i "s|WSS_URL=.*|WSS_URL=https://$webchat_url|" "$env_file"
    else
      echo "WSS_URL=https://$webchat_url" >> "$env_file"
    fi

    if grep -q "WSS_PORT=" "$env_file"; then
      sed -i "s|WSS_PORT=.*|WSS_PORT=$webchat_port|" "$env_file"
    else
      echo "WSS_PORT=$webchat_port" >> "$env_file"
    fi
  else
    printf "${RED} ❌ Arquivo .env não encontrado!${NC}\n\n"
    return 1
  fi

  # Configurar nginx
  sudo su - root <<EOF
  # Remover configuração antiga se existir
  rm -f "/etc/nginx/sites-available/$nginx_config"
  rm -f "/etc/nginx/sites-enabled/$nginx_config"

  # Criar nova configuração
  cat > "/etc/nginx/sites-available/$nginx_config" << 'END'
server {
  server_name $webchat_url;

  location / {
    proxy_pass http://127.0.0.1:$webchat_port;
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

  # Ativar configuração
  ln -sf "/etc/nginx/sites-available/$nginx_config" "/etc/nginx/sites-enabled/"

  # Verificar configuração do nginx
  if ! nginx -t; then
    printf "${RED} ❌ Erro na configuração do nginx!${NC}\n\n"
    exit 1
  fi

  # Reiniciar nginx
  systemctl restart nginx

  # Gerar certificado SSL
  certbot --nginx -d $webchat_url --redirect --non-interactive --agree-tos --email $ssl_email

  # Liberar porta no UFW
  ufw allow $webchat_port/tcp

  # Reiniciar todos os processos PM2
  sudo -u deployzdg pm2 restart all
  printf "${GREEN} ✅ Todos os processos PM2 reiniciados${NC}\n"
EOF

  print_banner
  printf "${GREEN} ✅ Webchat instalado com sucesso!${GRAY_LIGHT}\n\n"
  printf "${WHITE} 📊 Informações da instalação:${GRAY_LIGHT}\n"
  printf "  • Instância: $selected_instance\n"
  printf "  • URL do webchat: https://$webchat_url\n"
  printf "  • Porta do webchat: $webchat_port\n"
  printf "  • Configuração nginx: $nginx_config\n"
  printf "  • Porta liberada no UFW: $webchat_port/tcp\n\n"
  printf "${YELLOW} ⚠️  Lembre-se de atualizar o DNS do domínio para apontar para este servidor${NC}\n\n"

  sleep 2
}
