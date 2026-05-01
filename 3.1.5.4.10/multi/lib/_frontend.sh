#!/bin/bash
# 
# functions for setting up app frontend

#######################################
# installed node packages
# Arguments:
#   None
#######################################
frontend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/${folder_name}/zpro.io/frontend
  npm install --force
  npm i @quasar/cli
EOF

  sleep 2
}

#######################################
# compiles frontend code
# Arguments:
#   None
#######################################
frontend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/${folder_name}/zpro.io/frontend
  npm run build
EOF

  sleep 2
}

#######################################
# starts frontend using pm2 in 
# production mode.
# Arguments:
#   None
#######################################
frontend_remove_server_js() {
  print_banner
  printf "${WHITE} 💻 Removendo server.js (frontend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  cd /home/deployzdg/${folder_name}/zpro.io/frontend
  rm -f server.js
EOF

  sleep 2
}

#######################################
# starts frontend using pm2 in 
# production mode.
# Arguments:
#   None
#######################################
frontend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (frontend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # ensure idempotency
  backend_url=$(echo "${backend_url/https:\/\/}")
  backend_url=${backend_url%%/*}
  backend_url=https://$backend_url

sudo su - deployzdg << EOF
  cat <<[-]EOF > /home/deployzdg/${folder_name}/zpro.io/frontend/.env
  URL_API=${backend_url}
  FACEBOOK_APP_ID='23156312477653241'
[-]EOF
EOF

  sleep 2
}

#######################################
# sets frontend environment variables
# Arguments:
#   None
#######################################
frontend_set_server_js() {
  print_banner
  printf "${WHITE} 💻 Definindo porta para o frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2


sudo su - deployzdg << EOF
  cat <<[-]EOF > /home/deployzdg/${folder_name}/zpro.io/frontend/server.js
  // simple express server to run frontend production build;
  const express = require('express')
  const path = require('path')
  const app = express()
  app.use(express.static(path.join(__dirname, 'dist/pwa')))
  app.get('/*', function (req, res) {
    res.sendFile(path.join(__dirname, 'dist/pwa', 'index.html'))
  })
  app.listen(${frontend_port})

[-]EOF
EOF

  sleep 2
}

#######################################
# starts frontend using pm2 in 
# production mode.
# Arguments:
#   None
#######################################
frontend_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Iniciando pm2 (frontend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/${folder_name}/zpro.io/frontend
  pm2 start server.js --name ${folder_name}-zpro-frontend
  pm2 save
EOF

  sleep 2
}

#######################################
# sets up nginx for frontend
# Arguments:
#   None
#######################################
frontend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (frontend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  frontend_hostname=$(echo "${frontend_url/https:\/\/}")

sudo su - root << EOF

cat > /etc/nginx/sites-available/${folder_name}-zpro-frontend << 'END'
server {
  server_name $frontend_hostname;
  
    location / {
    proxy_pass http://127.0.0.1:${frontend_port};
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

ln -s /etc/nginx/sites-available/${folder_name}-zpro-frontend /etc/nginx/sites-enabled
EOF

  sleep 2
}
