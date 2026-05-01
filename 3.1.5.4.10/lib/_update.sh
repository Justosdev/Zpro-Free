#!/bin/bash
# 
# system management

#######################################
# installs node
# Arguments:
#   None
#######################################
update_node_install() {
  print_banner
  printf "${WHITE} 💻 Instalando nodejs...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  apt-get install -y nodejs
EOF

  sleep 2
}

#######################################
# installs node
# Arguments:
#   None
#######################################
update_bd_update() {
  print_banner
  printf "${WHITE} 💻 Atualizando permissões do banco...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  # Verifica se o contêiner está em execução
  if docker ps -q -f name=postgresql; then
    docker exec -u root postgresql bash -c "chown -R postgres:postgres /var/lib/postgresql/data"
  else
    echo "O contêiner postgresql não está em execução. Verifique o status do contêiner."
  fi
EOF

  sleep 2
}

#######################################
# stop all services
# Arguments:
#   None
#######################################
update_stop_pm2() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos para os serviços no deployzdg...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  pm2 stop all
  pm2 flush all
EOF

  sleep 2
}

#######################################
# move update folder
# Arguments:
#   None
#######################################
update_mv_zpro() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos mover a update até o deployzdg...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  cp "${PROJECT_ROOT}"/update.zip /home/deployzdg/
EOF

  sleep 2
}

#######################################
# delete backend folder
# Arguments:
#   None
#######################################
update_delete_backend() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos deletar o backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  cd /home/deployzdg/zpro.io/backend || exit
  rm -rf node_modules
  rm -rf dist
  rm -f package.json
  rm -f package-lock.json
EOF

  sleep 2
}

#######################################
# delete frontend folder
# Arguments:
#   None
#######################################
update_delete_frontend() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos deletar o frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  cd /home/deployzdg/zpro.io/frontend || exit
  # Remove conteúdo da pasta src exceto App.vue, index.template.html e pasta assets
  find src -mindepth 1 -not -name 'App.vue' -not -name 'index.template.html' -not -path 'src/assets/*' -exec rm -rf {} + 2>/dev/null || true
  # Remove diretórios
  rm -rf .quasar
  rm -rf dist
  rm -rf node_modules
  # rm -rf src-pwa
  # rm -rf src
  # Remove arquivos específicos do public
  rm -f public/POSTMAN_v2.json
  # Remove arquivos de configuração
  rm -f .DS_Store
  rm -f .editorconfig
  rm -f .eslintignore
  rm -f .eslintrc.js
  rm -f .gitignore
  rm -f .postcssrc.js
  rm -f .v-i18n-extractrc.json
  rm -f babel.config.js
  rm -f jsconfig.json
  rm -f package.json
  rm -f package-lock.json
  rm -f quasar.conf.js
  rm -f quasar.config.js
  rm -f quasar.extensions.json
  # Remove arquivos opcionais (se existirem)
  rm -f vercel.json
  rm -f vue-i18n-extract.config.js
  rm -f workspace.code-workspace
  # Verifica e copia logos se não existirem
  if [ ! -f "public/logo.png" ] && [ -f "public/zpro.png" ]; then
    cp public/zpro.png public/logo.png
  fi
  if [ ! -f "public/logo_dark.png" ] && [ -f "public/zpro_dark.png" ]; then
    cp public/zpro_dark.png public/logo_dark.png
  fi
EOF

  sleep 2
}

#######################################
# delete frontend folder
# Arguments:
#   None
#######################################
update_tos() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos atualizar os termos de uso...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  cd /home/deployzdg || exit
  rm -f aviso_de_privacidade.pdf
  rm -f termos_de_uso.pdf
EOF

  sleep 2
}

#######################################
# unzip update
# Arguments:
#   None
#######################################
update_unzip_zpro() {
  print_banner
  printf "${WHITE} 💻 Fazendo unzip da update...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  unzip update.zip
EOF

  sleep 2
}

#######################################
# check and copy index.html to frontend
# Arguments:
#   None
#######################################
update_check_frontend_index() {
  print_banner
  printf "${WHITE} 💻 Verificando arquivo index.html no frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  # Verifica se o arquivo index.html existe na pasta frontend
  if [ ! -f "/home/deployzdg/zpro.io/frontend/index.html" ]; then
    printf "${YELLOW} ⚠️  Arquivo index.html não encontrado no frontend. Copiando...${GRAY_LIGHT}\n"
    cp "${PROJECT_ROOT}/index.html" /home/deployzdg/zpro.io/frontend/
    printf "${GREEN} ✅ Arquivo index.html copiado com sucesso!${GRAY_LIGHT}\n"
  else
    printf "${GREEN} ✅ Arquivo index.html já existe no frontend.${GRAY_LIGHT}\n"
  fi

  # Verifica se o script do wavoip já existe no index.html
  if ! grep -q '<script src="https://cdn.jsdelivr.net/npm/@wavoip/wavoip-webphone/dist/index.umd.min.js"></script>' /home/deployzdg/zpro.io/frontend/index.html; then
    printf "${YELLOW} ⚠️  Script do wavoip não encontrado. Adicionando...${GRAY_LIGHT}\n"
    # Adiciona o script antes do fechamento do </head>
    sed -i '/<\/head>/i\    <script src="https://cdn.jsdelivr.net/npm/@wavoip/wavoip-webphone/dist/index.umd.min.js"></script>' /home/deployzdg/zpro.io/frontend/index.html
    printf "${GREEN} ✅ Script do wavoip adicionado com sucesso!${GRAY_LIGHT}\n"
  else
    printf "${GREEN} ✅ Script do wavoip já existe no index.html.${GRAY_LIGHT}\n"
  fi
EOF

  sleep 2
}

#######################################
# delete zip
# Arguments:
#   None
#######################################
update_delete_zip() {
  print_banner
  printf "${WHITE} 💻 Vamos delete o zip do update...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  cd /home/deployzdg || exit
  rm -f update.zip
EOF

  sleep 2
}

#######################################
# installs node.js dependencies
# Arguments:
#   None
#######################################
update_backend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  npm install --force
EOF

  sleep 2
}

#######################################
# runs db migrate
# Arguments:
#   None
#######################################
update_backend_db_migrate() {
  print_banner
  printf "${WHITE} 💻 Executando db:migrate...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  npx sequelize db:migrate
EOF

  sleep 2
}

#######################################
# runs db seed
# Arguments:
#   None
#######################################
update_backend_db_seed() {
  print_banner
  printf "${WHITE} 💻 Executando db:seed...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/backend
  npx sequelize db:seed:all
EOF

  sleep 2
}

#######################################
# installed node packages
# Arguments:
#   None
#######################################
update_frontend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/frontend
  npm install --force
EOF

  sleep 2
}

#######################################
# compiles frontend code
# Arguments:
#   None
#######################################
update_frontend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do frontend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  cd /home/deployzdg/zpro.io/frontend
  npm run build
EOF

  sleep 2
}

#######################################
# stop all services
# Arguments:
#   None
#######################################
update_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos reiniciar os serviços no deployzdg...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  pm2 restart all
EOF

  sleep 2
}

#######################################
# creates final message
# Arguments:
#   None
#######################################
update_success() {
  print_banner
  printf "${GREEN} 💻 Atualização concluída!${NC}"
  printf "\n\n"
  printf "Caso o sistema apresente alguma instabilidade, verifique os retornos dos processos rolando a barra lateral para cima, em busca de possíveis incosistências ou restaure o seu backup..."
  printf "\n"
  printf "Firewall foi ativado, liberando acesso as portas 22, 443, 80 e 9000"
  printf "\n\n"
  printf "${WHITE} 📊 URLs do sistema:${GRAY_LIGHT}"
  printf "\n"

  # Ler URLs do arquivo .env
  backend_url=$(grep "BACKEND_URL=" /home/deployzdg/zpro.io/backend/.env | cut -d'=' -f2)
  frontend_url=$(grep "FRONTEND_URL=" /home/deployzdg/zpro.io/backend/.env | cut -d'=' -f2)

  printf "  • Backend: ${backend_url}"
  printf "\n"
  printf "  • Frontend: ${frontend_url}"
  printf "\n\n"
  printf "${GREEN}FAQ: https://zpro.passaportezdg.com.br/${NC}"
  printf "\n"
  printf "${GREEN}Suporte: https://passaportezdg.tomticket.com/${NC}"
  printf "\n"
  printf "${CYAN_LIGHT}";
  printf "${NC}";

  sleep 2
}