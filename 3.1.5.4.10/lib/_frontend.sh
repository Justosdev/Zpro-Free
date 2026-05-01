#!/bin/bash
#
# functions for setting up app frontend

#######################################
# installs node packages
# Arguments:
#   None
#######################################
frontend_node_dependencies() {
  step_header "📦" "Instalando dependências do frontend" \
    "Executa npm install --force em /home/deployzdg/zpro.io/frontend."
  printf "  ${DIM}Instala o Quasar Framework, Vue.js, plugins de i18n e todas as dependências${NC}\n"
  printf "  ${DIM}do frontend. Inclui @quasar/cli para o build. Pode levar 3-5 minutos.${NC}\n\n"

  start_spinner "Instalando pacotes npm do frontend (pode demorar alguns minutos)..."
  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/frontend
  npm install --force
  npm i @quasar/cli
EOF
  stop_spinner "Dependências do frontend instaladas."
  sleep 1
}

#######################################
# compiles frontend code
# Arguments:
#   None
#######################################
frontend_node_build() {
  step_header "🔨" "Compilando o frontend" \
    "Executa npm run build — compila o código Vue.js/Quasar para produção."
  printf "  ${DIM}Gera os arquivos estáticos otimizados em /home/deployzdg/zpro.io/frontend/dist.${NC}\n"
  printf "  ${DIM}Esta é a etapa mais longa da instalação — pode levar de 3 a 8 minutos.${NC}\n\n"

  start_spinner "Compilando frontend para produção (aguarde, pode demorar vários minutos)..."
  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/frontend
  npm run build
EOF
  stop_spinner "Frontend compilado. Arquivos de produção gerados."
  sleep 1
}

#######################################
# sets frontend environment variables
# Arguments:
#   None
#######################################
frontend_set_env() {
  step_header "⚙️ " "Configurando variáveis de ambiente do frontend" \
    "Cria /home/deployzdg/zpro.io/frontend/.env com a URL da API."
  printf "  ${DIM}URL_API aponta para o backend — o frontend usa para fazer as chamadas REST e WebSocket.${NC}\n\n"

  sleep 1

  # ensure idempotency
  backend_url=$(echo "${backend_url/https:\/\/}")
  backend_url=${backend_url%%/*}
  backend_url=https://$backend_url

sudo su - deployzdg << EOF
  cat <<[-]EOF > /home/deployzdg/zpro.io/frontend/.env
  URL_API=${backend_url}
  FACEBOOK_APP_ID='23156312477653241'
[-]EOF
EOF

  printf "  ${GREEN}✅${NC}  .env do frontend criado. URL_API: ${backend_url}\n\n"
  sleep 1
}

#######################################
# starts frontend using pm2 in production mode
# Arguments:
#   None
#######################################
frontend_start_pm2() {
  step_header "🚀" "Iniciando frontend com PM2" \
    "Inicia o servidor do frontend com PM2 na porta 4444."
  printf "  ${DIM}Processo: zpro-frontend | O nginx encaminha requisições HTTPS para esta porta.${NC}\n\n"

  start_spinner "Iniciando zpro-frontend na porta 4444..."
  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/frontend
  pm2 start server.js --name zpro-frontend
  pm2 save
EOF
  stop_spinner "Frontend iniciado. Processo zpro-frontend ativo no PM2."
  sleep 1
}

#######################################
# sets up nginx for frontend
# Arguments:
#   None
#######################################
frontend_nginx_setup() {
  step_header "🌐" "Configurando nginx para o frontend" \
    "Cria /etc/nginx/sites-available/zpro-frontend e ativa o vhost."
  printf "  ${DIM}O nginx recebe requisições HTTPS no domínio ${frontend_url} e encaminha${NC}\n"
  printf "  ${DIM}para o frontend Node.js rodando em http://127.0.0.1:4444.${NC}\n\n"

  sleep 1

  frontend_hostname=$(echo "${frontend_url/https:\/\/}")

sudo su - root << EOF

cat > /etc/nginx/sites-available/zpro-frontend << 'END'
server {
  server_name $frontend_hostname;

    location / {
    proxy_pass http://127.0.0.1:4444;
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

ln -s /etc/nginx/sites-available/zpro-frontend /etc/nginx/sites-enabled
EOF

  printf "  ${GREEN}✅${NC}  vhost zpro-frontend criado e ativado no nginx.\n\n"
  sleep 1
}
