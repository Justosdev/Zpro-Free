#!/bin/bash
#
# system management

#######################################
# Verifica se o SO é Ubuntu 20.04, 22.04 ou 24.04
# Arguments:
#   None
#######################################
system_check_os() {
  step_header "🔍" "Verificando sistema operacional" \
    "Este instalador suporta apenas Ubuntu 20.04 LTS, 22.04 LTS e 24.04 LTS."

  local distro version
  distro=$(lsb_release -is 2>/dev/null)
  version=$(lsb_release -rs 2>/dev/null)

  if [[ "$distro" != "Ubuntu" ]]; then
    printf "  ${RED}❌  Sistema não suportado: ${distro:-desconhecido}${NC}\n\n"
    printf "  ${WHITE}Use apenas Ubuntu 20.04, 22.04 ou 24.04.${NC}\n\n"
    exit 1
  fi

  case "$version" in
    20.04|22.04|24.04)
      printf "  ${GREEN}✅  Ubuntu ${version} LTS detectado — compatível.${NC}\n\n"
      ;;
    *)
      printf "  ${RED}❌  Versão não suportada: Ubuntu ${version}${NC}\n\n"
      printf "  ${WHITE}Use apenas Ubuntu 20.04, 22.04 ou 24.04.${NC}\n\n"
      exit 1
      ;;
  esac

  sleep 1
}

#######################################
# Verifica se a porta 80 está livre para o nginx
# Arguments:
#   None
#######################################
system_check_port_80() {
  step_header "🔍" "Verificando porta 80" \
    "O nginx precisa da porta 80 para receber requisições HTTP e para o Certbot emitir certificados SSL."

  if ss -tlnp 'sport = :80' 2>/dev/null | grep -q LISTEN; then
    printf "  ${RED}❌  A porta 80 está em uso!${NC}\n\n"
    printf "  ${WHITE}Processo(s) ocupando a porta 80:${NC}\n"
    ss -tlnp 'sport = :80' | grep LISTEN
    printf "\n"
    printf "  ${YELLOW}⚠️   Encerre o processo que ocupa a porta 80 antes de instalar.${NC}\n\n"
    exit 1
  fi

  printf "  ${GREEN}✅  Porta 80 disponível.${NC}\n\n"
  sleep 1
}

#######################################
# Cria o usuário deployzdg que executa a aplicação
# Arguments:
#   None
#######################################
system_create_user() {
  step_header "👤" "Criando usuário deployzdg" \
    "A aplicação ZPRO roda sob o usuário 'deployzdg' (sem privilégios root diretos)."
  printf "  ${DIM}Esse usuário é dono de todos os arquivos da aplicação e dos processos PM2.${NC}\n\n"

  # Em modo dev, pula criação de usuário
  if [[ "${ZPRO_DEV:-}" == "1" ]]; then
    printf "  ${YELLOW}[DEV] Pulando criação de usuário deployzdg.${NC}\n\n"
    sleep 1
    return 0
  fi

  # Se o usuário já existe, apenas garante que o zip foi copiado
  if id "deployzdg" &>/dev/null; then
    printf "  ${YELLOW}⚠️   Usuário deployzdg já existe. Pulando criação.${NC}\n\n"
    sudo su - root <<EOF
    cp "${PROJECT_ROOT}"/zpro.zip /home/deployzdg/ 2>/dev/null || true
EOF
    sleep 2
    return 0
  fi

  start_spinner "Criando usuário e configurando senha..."
  if ! sudo su - root <<EOF 2>/dev/null
  useradd -m -s /bin/bash deployzdg
  usermod -aG sudo deployzdg
  echo "deployzdg:${deploy_password}" | chpasswd
  cp "${PROJECT_ROOT}"/zpro.zip /home/deployzdg/
EOF
  then
    stop_spinner_error "Falha ao criar o usuário deployzdg."
    printf "\n  ${WHITE}Possíveis soluções:${NC}\n"
    printf "  ${YELLOW}1. Execute manualmente: ${NC}sudo adduser deployzdg\n"
    printf "  ${YELLOW}2. Reinicie o processo de instalação${NC}\n\n"
    printf "  ${WHITE}Pressione qualquer tecla para sair...${NC}\n"
    read -n 1 -s
    exit 1
  fi
  stop_spinner "Usuário deployzdg criado com senha definida via chpasswd."
  sleep 1
}

#######################################
# Configura o timezone do servidor
# Arguments:
#   None
#######################################
system_set_timezone() {
  step_header "🕐" "Configurando timezone" \
    "Define America/Sao_Paulo como timezone do servidor via timedatectl."
  printf "  ${DIM}Importante para logs, agendamentos e timestamps corretos no banco de dados.${NC}\n\n"

  start_spinner "Definindo timezone para America/Sao_Paulo..."
  sudo su - root <<EOF
  timedatectl set-timezone America/Sao_Paulo
EOF
  stop_spinner "Timezone configurado: America/Sao_Paulo."
  sleep 1
}

#######################################
# Extrai o arquivo zpro.zip
# Arguments:
#   None
#######################################
system_unzip_zpro() {
  step_header "📦" "Extraindo zpro.zip" \
    "Descompacta o pacote da aplicação em /home/deployzdg/zpro.io."
  printf "  ${DIM}Contém o backend (Node.js/TypeScript) e o frontend (Vue.js/Quasar).${NC}\n\n"

  start_spinner "Extraindo zpro.zip em /home/deployzdg/..."
  sudo su - deployzdg <<EOF
  unzip -q zpro.zip
EOF
  stop_spinner "Pacote extraído em /home/deployzdg/zpro.io."
  sleep 1
}

#######################################
# Atualiza os pacotes do sistema
# Arguments:
#   None
#######################################
system_update() {
  step_header "🔄" "Atualizando pacotes do sistema" \
    "Executa apt update + apt full-upgrade para garantir que o Ubuntu esteja"
  printf "  ${DIM}completamente atualizado antes das instalações. Pode demorar alguns minutos.${NC}\n\n"

  start_spinner "Baixando e instalando atualizações do sistema..."
  sudo su - root <<EOF
  apt -y update && apt -y full-upgrade
EOF
  stop_spinner "Sistema atualizado."
  sleep 1
}

#######################################
# Instala Node.js 20 LTS
# Arguments:
#   None
#######################################
system_node_install() {
  step_header "⬢" "Instalando Node.js 20 LTS" \
    "Adiciona o repositório oficial NodeSource e instala Node.js 20 LTS via apt."
  printf "  ${DIM}Node.js é o runtime JavaScript que executa o backend e compila o frontend.${NC}\n\n"

  start_spinner "Configurando repositório NodeSource e instalando Node.js 20..."
  sudo su - root <<EOF
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  apt-get install -y nodejs
EOF
  stop_spinner "Node.js $(node --version 2>/dev/null || echo 'instalado')."
  sleep 1
}

#######################################
# Instala Docker CE
# Arguments:
#   None
#######################################
system_docker_install() {
  step_header "🐳" "Instalando Docker CE" \
    "Instala o Docker Community Edition via repositório oficial com chave GPG verificada."
  printf "  ${DIM}Docker é usado para rodar PostgreSQL, Redis e Portainer como containers isolados,${NC}\n"
  printf "  ${DIM}garantindo que não conflitem com outros serviços do servidor.${NC}\n\n"

  start_spinner "Adicionando repositório Docker e instalando Docker CE..."
  sudo su - root <<EOF
  apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io
EOF
  stop_spinner "Docker CE instalado (repositório compatível com $(lsb_release -rs 2>/dev/null))."
  sleep 1
}

#######################################
# Instala dependências do Puppeteer / Chrome headless
# Arguments:
#   None
#######################################
system_puppeteer_dependencies() {
  step_header "🖥️ " "Instalando dependências do Puppeteer" \
    "Instala ~30 bibliotecas gráficas do sistema operacional necessárias para o"
  printf "  ${DIM}Chrome/Chromium rodar em modo headless (sem interface gráfica).${NC}\n"
  printf "  ${DIM}Usado pelo backend para geração de PDFs de conversas e capturas de tela.${NC}\n\n"

  start_spinner "Instalando bibliotecas gráficas (libgtk, libnss, libx11, ffmpeg...)..."
  sudo su - root <<EOF
  apt-get install -y libxshmfence-dev \
                      libgbm-dev \
                      wget \
                      unzip \
                      fontconfig \
                      locales \
                      gconf-service \
                      libasound2 \
                      libatk1.0-0 \
                      libc6 \
                      libcairo2 \
                      libcups2 \
                      libdbus-1-3 \
                      libexpat1 \
                      libfontconfig1 \
                      libgcc1 \
                      libgconf-2-4 \
                      libgdk-pixbuf2.0-0 \
                      libglib2.0-0 \
                      libgtk-3-0 \
                      libnspr4 \
                      libpango-1.0-0 \
                      libpangocairo-1.0-0 \
                      libstdc++6 \
                      libx11-6 \
                      libx11-xcb1 \
                      libxcb1 \
                      libxcomposite1 \
                      libxcursor1 \
                      libxdamage1 \
                      libxext6 \
                      libxfixes3 \
                      libxi6 \
                      libxrandr2 \
                      libxrender1 \
                      libxss1 \
                      libxtst6 \
                      ca-certificates \
                      fonts-liberation \
                      libappindicator1 \
                      libnss3 \
                      lsb-release \
                      xdg-utils \
                      git \
                      libssl-dev \
                      ffmpeg
EOF
  stop_spinner "Dependências do Puppeteer instaladas."
  sleep 1
}

#######################################
# Instala bibliotecas adicionais do sistema
# Arguments:
#   None
#######################################
system_libs() {
  step_header "📚" "Instalando bibliotecas do sistema" \
    "Instala python2-minimal, build-essential e unzip — dependências de compilação"
  printf "  ${DIM}necessárias para alguns pacotes npm que precisam compilar código nativo (C/C++).${NC}\n\n"

  start_spinner "Instalando build-essential, python2 e unzip..."
  sudo su - root <<EOF
  apt-add-repository universe
  apt install -y python2-minimal
  apt-get install -y build-essential
  apt -y update && apt -y full-upgrade
  apt install unzip -y
EOF
  stop_spinner "Bibliotecas do sistema instaladas."
  sleep 1
}

#######################################
# Instala PM2 (gerenciador de processos Node.js)
# Arguments:
#   None
#######################################
system_pm2_install() {
  step_header "⚙️ " "Instalando PM2" \
    "PM2 é o gerenciador de processos Node.js em produção."
  printf "  ${DIM}Mantém o backend e frontend rodando em segundo plano, reinicia automaticamente${NC}\n"
  printf "  ${DIM}em caso de falha, gerencia logs e inicializa os processos na inicialização do servidor.${NC}\n\n"

  start_spinner "Instalando PM2 globalmente e configurando startup para deployzdg..."
  sudo su - root <<EOF
  npm install -g pm2
  pm2 startup ubuntu -u deployzdg
  env PATH=\$PATH:/usr/bin pm2 startup ubuntu -u deployzdg --hp /home/deployzdg
EOF
  stop_spinner "PM2 instalado e configurado para iniciar com o servidor."
  sleep 1
}

#######################################
# Instala snapd (necessário para Certbot)
# Arguments:
#   None
#######################################
system_snapd_install() {
  step_header "📦" "Instalando snapd" \
    "Snapd é o gerenciador de pacotes Snap, necessário para instalar o Certbot"
  printf "  ${DIM}no método recomendado pela Let's Encrypt (mais atualizado que o apt).${NC}\n\n"

  start_spinner "Instalando snapd e atualizando core snap..."
  sudo su - root <<EOF
  apt install -y snapd
  snap install core
  snap refresh core
EOF
  stop_spinner "Snapd instalado e atualizado."
  sleep 1
}

#######################################
# Instala Certbot via snap
# Arguments:
#   None
#######################################
system_certbot_install() {
  step_header "🔒" "Instalando Certbot" \
    "Certbot é a ferramenta da Let's Encrypt para emitir e renovar certificados SSL/TLS gratuitos."
  printf "  ${DIM}Instalado via snap (método oficial recomendado). Cria symlink em /usr/bin/certbot.${NC}\n"
  printf "  ${DIM}Os certificados são renovados automaticamente a cada 90 dias.${NC}\n\n"

  start_spinner "Instalando Certbot via snap..."
  sudo su - root <<EOF
  apt-get remove certbot
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot
EOF
  stop_spinner "Certbot instalado em /usr/bin/certbot."
  sleep 1
}

#######################################
# Instala nginx
# Arguments:
#   None
#######################################
system_nginx_install() {
  step_header "🌐" "Instalando nginx" \
    "nginx é o servidor web / proxy reverso que recebe as requisições HTTP/HTTPS"
  printf "  ${DIM}e encaminha para o backend (porta 3000) e frontend (porta 4444).${NC}\n"
  printf "  ${DIM}Também serve os arquivos estáticos e termina as conexões SSL.${NC}\n\n"

  start_spinner "Instalando nginx e removendo vhost padrão..."
  sudo su - root <<EOF
  apt install -y nginx
  rm /etc/nginx/sites-enabled/default
EOF
  stop_spinner "nginx instalado. Vhost padrão removido."
  sleep 1
}

#######################################
# Adiciona deployzdg ao grupo docker
# Arguments:
#   None
#######################################
system_set_user_mod() {
  step_header "🔐" "Configurando permissões do usuário" \
    "Adiciona o usuário deployzdg ao grupo docker para que ele possa interagir"
  printf "  ${DIM}com os containers (PostgreSQL, Redis) sem precisar de sudo.${NC}\n\n"

  start_spinner "Adicionando deployzdg ao grupo docker..."
  sudo su - root <<EOF
  sudo usermod -aG docker deployzdg
  su - deployzdg
EOF
  stop_spinner "deployzdg adicionado ao grupo docker."
  sleep 1
}

#######################################
# Reinicia nginx
# Arguments:
#   None
#######################################
system_nginx_restart() {
  step_header "🔄" "Reiniciando nginx" \
    "Aplica todas as configurações de vhost criadas para backend e frontend."

  start_spinner "Reiniciando nginx..."
  sudo su - root <<EOF
  service nginx restart
EOF
  stop_spinner "nginx reiniciado com sucesso."
  sleep 1
}

#######################################
# Configura nginx.conf (buffers, timeout, worker_connections)
# Arguments:
#   None
#######################################
system_nginx_conf() {
  step_header "⚙️ " "Otimizando configuração do nginx" \
    "Aplica configurações de performance e limites para suportar a carga do ZPRO:"
  printf "  ${DIM}• client_max_body_size 64M — permite uploads de até 64MB${NC}\n"
  printf "  ${DIM}• proxy_read_timeout 86400 — mantém WebSockets ativos por até 24h${NC}\n"
  printf "  ${DIM}• worker_connections 2048 — suporta mais conexões simultâneas${NC}\n\n"

  start_spinner "Criando /etc/nginx/conf.d/zproio.conf e ajustando nginx.conf..."
sudo su - root << EOF

cat > /etc/nginx/conf.d/zproio.conf << 'END'
client_max_body_size 64M;
large_client_header_buffers 4 16k;
client_body_buffer_size 16k;
proxy_buffer_size 32k;
proxy_buffers 8 32k;
proxy_connect_timeout 60;
proxy_read_timeout 86400;
proxy_send_timeout 86400;
END

if [ -f /etc/nginx/nginx.conf ]; then
  sed -i 's/worker_connections 768/worker_connections 2048/' /etc/nginx/nginx.conf
  sed -i 's/# multi_accept on;/multi_accept on;/' /etc/nginx/nginx.conf
fi

EOF
  stop_spinner "nginx otimizado: buffers, timeouts e worker_connections configurados."
  sleep 1
}

#######################################
# Configura e emite certificados SSL via Certbot
# Arguments:
#   None
#######################################
system_certbot_setup() {
  step_header "🔒" "Emitindo certificados SSL" \
    "Certbot se comunica com os servidores da Let's Encrypt para validar os domínios"
  printf "  ${DIM}via desafio HTTP (porta 80) e emitir certificados SSL gratuitos.${NC}\n"
  printf "  ${DIM}Configura redirecionamento automático HTTP → HTTPS no nginx.${NC}\n\n"

  backend_domain=$(echo "${backend_url/https:\/\/}")
  frontend_domain=$(echo "${frontend_url/https:\/\/}")
  admin_domain=$(echo "${admin_url/https:\/\/}")

  printf "  ${DIM}Domínios: ${backend_domain}, ${frontend_domain}${NC}\n\n"

  start_spinner "Emitindo certificados SSL para os domínios configurados..."
  sudo su - root <<EOF
  certbot -m $deploy_email \
          --nginx \
          --agree-tos \
          --redirect \
          --non-interactive \
          --domains $backend_domain,$frontend_domain
EOF
  stop_spinner "Certificados SSL emitidos. HTTPS ativo em ambos os domínios."
  sleep 1
}

#######################################
# Reinicia o servidor
# Arguments:
#   None
#######################################
system_reboot() {
  step_header "🔁" "Reiniciando servidor" \
    "Reinicialização necessária para aplicar alterações de kernel ou grupos de usuário."

  start_spinner "Reiniciando em 3 segundos..."
  sleep 3
  sudo su - root <<EOF
  reboot
EOF
}

#######################################
# Inicia containers Docker parados
# Arguments:
#   None
#######################################
system_docker_start() {
  step_header "🐳" "Iniciando containers Docker" \
    "Inicia os containers PostgreSQL e Redis que podem ter parado."

  start_spinner "Iniciando containers postgresql e redis-zpro..."
  sudo su - root <<EOF
  docker stop $(docker ps -q)
  docker container start postgresql
  docker container start redis-zpro
EOF
  stop_spinner "Containers iniciados."
  sleep 1
}

#######################################
# Reinicia containers Docker
# Arguments:
#   None
#######################################
system_docker_restart() {
  step_header "🐳" "Reiniciando containers Docker" \
    "Reinicia Portainer e PostgreSQL para garantir que estejam prontos para receber conexões."

  start_spinner "Reiniciando portainer e postgresql (aguardando 10s)..."
  sudo su - root <<EOF
  docker container restart portainer
  docker container restart postgresql
EOF
  sleep 10
  stop_spinner "Containers reiniciados e prontos."
  sleep 1
}

#######################################
# Remove o zip de instalação
# Arguments:
#   None
#######################################
system_delete_zip() {
  step_header "🗑️ " "Removendo arquivo de instalação" \
    "Remove zpro.zip de /home/deployzdg — o arquivo não é mais necessário após a extração."

  start_spinner "Removendo zpro.zip..."
  sudo su - root <<EOF
  cd /home/deployzdg || exit
  rm -f zpro.zip
EOF
  stop_spinner "zpro.zip removido."
  sleep 1
}

#######################################
# Tela de conclusão da instalação
# Arguments:
#   None
#######################################
system_success() {
  local public_ip
  public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "N/D")

  print_banner
  printf "\033[1;92m  ✅  Instalação concluída com sucesso!\033[0m\n"
  printf "${GREEN}${DLINE}${NC}\n\n"

  printf "${GREEN}  ACESSO AO SISTEMA${NC}\n"
  printf "${DIM}${LINE}${NC}\n"
  printf "  ${DIM}SuperAdmin :${NC}  superadmin@zpro.io  ${DIM}/ senha:${NC}  \033[1;92m123456${NC}\n"
  printf "  ${DIM}Admin      :${NC}  admin@zpro.io       ${DIM}/ senha:${NC}  \033[1;92m123456${NC}\n"
  printf "  ${DIM}Frontend   :${NC}  \033[1;92mhttps://${frontend_domain}${NC}\n"
  printf "  ${DIM}Backend    :${NC}  \033[1;92mhttps://${backend_domain}${NC}\n"
  printf "\n"

  printf "${GREEN}  INFRAESTRUTURA${NC}\n"
  printf "${DIM}${LINE}${NC}\n"
  printf "  ${DIM}Portainer  :${NC}  \033[1;92mhttp://${public_ip}:9000${NC}  ${DIM}(HTTPS: 9443)${NC}\n"
  printf "  ${DIM}           :${NC}  senha: \033[1;92m${portainer_pass}${NC}\n"
  printf "  ${DIM}PostgreSQL :${NC}  localhost:5433  ${DIM}/ usuário: postgres / senha:${NC}  \033[1;92m${pg_pass}${NC}\n"
  printf "  ${DIM}Redis      :${NC}  localhost:6379  ${DIM}/ senha:${NC}  \033[1;92m${redis_pass}${NC}\n"
  printf "\n"

  printf "${GREEN}  SERVIDOR${NC}\n"
  printf "${DIM}${LINE}${NC}\n"
  printf "  ${DIM}Usuário    :${NC}  \033[1;92mdeployzdg${NC}\n"
  printf "  ${DIM}Senha      :${NC}  \033[1;92m${deploy_password}${NC}\n"
  printf "  ${DIM}Processos  :${NC}  zpro-backend  |  zpro-frontend  ${DIM}(PM2)${NC}\n"
  printf "  ${DIM}Firewall   :${NC}  UFW ativo — portas: 22, 80, 443, 9000\n"
  printf "\n"

  printf "${GREEN}  PRÓXIMOS PASSOS${NC}\n"
  printf "${DIM}${LINE}${NC}\n"
  printf "  ${DIM}1.${NC}  Acesse o Portainer e altere a senha padrão\n"
  printf "  ${DIM}2.${NC}  Faça login no ZPRO e configure os canais de atendimento\n"
  printf "  ${DIM}3.${NC}  Altere a senha do superadmin@zpro.io nas configurações\n"
  printf "  ${DIM}4.${NC}  Guarde as credenciais acima em local seguro\n"
  printf "\n"

  printf "${GREEN}${DLINE}${NC}\n"
  printf "${DIM}  Suporte : https://passaportezdg.tomticket.com/${NC}\n"
  printf "${DIM}  FAQ     : https://zpro.passaportezdg.com.br/${NC}\n"
  printf "${GREEN}${DLINE}${NC}\n\n"

  sleep 2
}
