#!/bin/bash
# 
# system management para atualização de instâncias secundárias

#######################################
# Percorre todas as instalações dentro de /home/deployzdg/
# e executa a atualização para cada pasta zpro.io encontrada.
#######################################
update_all_instances() {
  warn_snapshot_required "atualização de instâncias secundárias" || return 1
  rollback_ask_mode

  for instance in /home/deployzdg/*/zpro.io; do
    if [ -d "$instance" ]; then
      instance_name=$(echo "$instance" | grep -oP '(?<=/home/deployzdg/)[^/]+(?=/zpro\.io)')
      if [ -n "$instance_name" ]; then
        if [[ "${ROLLBACK_WITH_DUMP}" != "skip" ]]; then
          rollback_create_instance_backup "$instance" "$instance_name"
        fi
        echo "\n🚀 Atualizando instância: $instance_name"
        update_instance "$instance" "$instance_name"
      fi
    fi
  done
}

#######################################
# Executa a atualização em uma instância específica
# Arguments:
#   $1 - Caminho da instância (ex: /home/deployzdg/install1/zpro.io)
#   $2 - Nome da instância
#######################################
update_instance() {
  local INSTANCE_PATH="$1"
  local INSTANCE_NAME="$2"

  print_banner
  printf "${WHITE} 💻 Atualizando instância $INSTANCE_NAME em $INSTANCE_PATH...${GRAY_LIGHT}\n\n"

  sleep 2

  # Parar serviços PM2
  sudo su - deployzdg <<EOF
  pm2 stop all
  pm2 flush all
EOF

  sleep 2

  # Copiar arquivo de atualização
  sudo su - root <<EOF
  cp "${PROJECT_ROOT}"/update.zip "$INSTANCE_PATH/.."
EOF

  sleep 2

  # Limpar backend
  sudo su - root <<EOF
  cd "$INSTANCE_PATH/backend" || exit
  rm -rf node_modules dist package.json package-lock.json
EOF

  sleep 2

  # Limpar frontend
  sudo su - root <<EOF
  cd "$INSTANCE_PATH/frontend" || exit
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
  # rm -f index.html
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

  # Extrair atualização
  sudo su - deployzdg <<EOF
  cd "$INSTANCE_PATH/.."
  unzip update.zip
  rm -f update.zip
EOF

  sleep 2

  # Verificar e copiar index.html se necessário
  sudo su - deployzdg <<EOF
  # Verifica se o arquivo index.html existe na pasta frontend da instância
  if [ ! -f "$INSTANCE_PATH/frontend/index.html" ]; then
    printf "${YELLOW} ⚠️  Arquivo index.html não encontrado no frontend da instância $INSTANCE_NAME. Copiando...${GRAY_LIGHT}\n"
    cp "${PROJECT_ROOT}/index.html" "$INSTANCE_PATH/frontend/"
    printf "${GREEN} ✅ Arquivo index.html copiado com sucesso para $INSTANCE_PATH/frontend!${GRAY_LIGHT}\n"
  else
    printf "${GREEN} ✅ Arquivo index.html já existe no frontend da instância $INSTANCE_NAME.${GRAY_LIGHT}\n"
  fi

  # Verifica se o script do wavoip já existe no index.html
  if ! grep -q '<script src="https://cdn.jsdelivr.net/npm/@wavoip/wavoip-webphone/dist/index.umd.min.js"></script>' "$INSTANCE_PATH/frontend/index.html"; then
    printf "${YELLOW} ⚠️  Script do wavoip não encontrado. Adicionando...${GRAY_LIGHT}\n"
    # Adiciona o script antes do fechamento do </head>
    sed -i '/<\/head>/i\    <script src="https://cdn.jsdelivr.net/npm/@wavoip/wavoip-webphone/dist/index.umd.min.js"></script>' "$INSTANCE_PATH/frontend/index.html"
    printf "${GREEN} ✅ Script do wavoip adicionado com sucesso!${GRAY_LIGHT}\n"
  else
    printf "${GREEN} ✅ Script do wavoip já existe no index.html.${GRAY_LIGHT}\n"
  fi
EOF

  sleep 2

  # Instalar dependências do backend
  sudo su - deployzdg <<EOF
  cd "$INSTANCE_PATH/backend"
  npm install --force
  npx sequelize db:migrate
EOF

  sleep 2

  # Instalar dependências do frontend
  sudo su - deployzdg <<EOF
  cd "$INSTANCE_PATH/frontend"
  npm install --force
  npm run build
EOF

  sleep 2

  # Reiniciar serviços
  sudo su - deployzdg <<EOF
  pm2 restart all
EOF

  sleep 2

  printf "${GREEN} ✅ Instância $INSTANCE_NAME atualizada com sucesso!${NC}\n"
}

#######################################
# Cria mensagem final
# Arguments:
#   None
#######################################
update_instances_success() {
  print_banner
  printf "${GREEN} 💻 Atualização de todas as instâncias concluída!${NC}"
  printf "\n\n"
  printf "${WHITE} 📊 Instâncias atualizadas:${GRAY_LIGHT}\n\n"

  # Percorrer todas as instâncias para mostrar informações
  for instance in /home/deployzdg/*/zpro.io; do
    if [ -d "$instance" ]; then
      instance_name=$(echo "$instance" | grep -oP '(?<=/home/deployzdg/)[^/]+(?=/zpro\.io)')
      if [ -n "$instance_name" ]; then
        # Ler URLs do arquivo .env do backend
        if [ -f "$instance/backend/.env" ]; then
          backend_url=$(grep "BACKEND_URL=" "$instance/backend/.env" | cut -d'=' -f2)
          frontend_url=$(grep "FRONTEND_URL=" "$instance/backend/.env" | cut -d'=' -f2)
          
          printf "  • Instância: ${YELLOW}$instance_name${NC}\n"
          printf "    - Pasta: ${GRAY_LIGHT}$instance${NC}\n"
          printf "    - Backend: ${GREEN}$backend_url${NC}\n"
          printf "    - Frontend: ${GREEN}$frontend_url${NC}\n\n"
        fi
      fi
    fi
  done

  printf "${YELLOW} ⚠️  Caso o sistema apresente alguma instabilidade, verifique os retornos dos processos rolando a barra lateral para cima, em busca de possíveis incosistências ou restaure o seu backup...${NC}"
  printf "\n"
  printf "${GREEN}FAQ: https://zpro.passaportezdg.com.br/${NC}"
  printf "\n"
  printf "${GREEN}Suporte: https://passaportezdg.tomticket.com/${NC}"
  printf "\n"
  printf "${CYAN_LIGHT}";
  printf "${NC}";

  sleep 2
} 