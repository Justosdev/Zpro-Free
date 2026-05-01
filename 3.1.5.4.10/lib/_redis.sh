#!/bin/bash

# Função para verificar se o Redis está rodando
check_redis_status() {
  print_banner
  printf "${WHITE} 💻 Verificando o status do Redis...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  systemctl status redis-server | grep "active (running)"
  if [ $? -eq 0 ]; then
    printf "${GREEN} Redis está rodando!${NC}\n"
  else
    printf "${RED} Redis não está rodando! Verificando logs...${NC}\n"
    journalctl -u redis-server.service -b | tail -n 20
  fi
EOF

  sleep 2
}

# Função para listar o container Redis rodando no Docker e matar ele
docker_list_and_kill_redis() {
  print_banner
  printf "${WHITE} 💻 Listando e matando container Redis no Docker...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root <<EOF
  docker ps | grep redis
  docker kill \$(docker ps | grep redis | awk '{print \$1}')
EOF

  sleep 2
}

# Função para ler o arquivo .env e pegar o password do Redis
get_redis_password() {
  print_banner
  printf "${WHITE} 💻 Lendo o arquivo .env e pegando a senha do Redis...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  redis_password=$(grep -oP '(?<=IO_REDIS_PASSWORD=).+' /home/deployzdg/zpro.io/backend/.env)
  echo "Senha do Redis: \$redis_password"
}

# Função para criar o serviço Redis no Ubuntu
create_redis_service() {
  print_banner
  printf "${WHITE} 💻 Criando serviço Redis no Ubuntu...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  get_redis_password

  sudo su - root <<EOF
  apt-get update
  apt-get install -y redis-server

  # Configurando senha do Redis
  sed -i "s/^# requirepass .*/requirepass $redis_password/" /etc/redis/redis.conf

  # Configurando outras opções necessárias
  sed -i "s/^supervised no/supervised systemd/" /etc/redis/redis.conf
  sed -i "s/^# appendonly .*/appendonly yes/" /etc/redis/redis.conf

  systemctl restart redis-server
  systemctl enable redis-server
EOF

  sleep 2
}

#######################################
# stop all services
# Arguments:
#   None
#######################################
redis_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos reiniciar os serviços no deployzdg...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - deployzdg <<EOF
  pm2 restart all
EOF

  sleep 2
}