#!/bin/bash
#
# Print banner art.

print_banner() {
  clear
  printf "${GREEN}${DLINE}${NC}\n"
  # sombra — deslocada 1 char à direita, verde escuro dim
  printf "\033[2;32m"
  printf "   █████████      ███████         █████████\n"
  printf "         ███      ███    ██       ███      \n"
  printf "       ███        ███    ███      ███      \n"
  printf "     ███          ███    ███      ███  ████\n"
  printf "   ███            ███    ██       ███    ██\n"
  printf "   █████████      ███████         █████████ FREE\n"
  printf "${NC}"
  # sobe 6 linhas e imprime o logo com gradiente verde por cima
  printf "\033[6A"
  printf "\033[1;92m"
  printf "  █████████      ███████         █████████\n"
  printf "\033[92m"
  printf "        ███      ███    ██       ███      \n"
  printf "\033[1;32m"
  printf "      ███        ███    ███      ███      \n"
  printf "    ███          ███    ███      ███  ████\n"
  printf "\033[0;32m"
  printf "  ███            ███    ██       ███    ██\n"
  printf "  █████████      ███████         █████████ FREE\n"
  printf "${NC}"
  printf "${DIM}  Plataforma de Multiatendimento — Z-PRO Free Edition ${NC}\n"
  printf "${DIM}  Solução sob licença MIT${NC}\n"
  printf "${GREEN}${LINE}${NC}\n"
  local _cpu _cores _ram_total _ram_used _ram_free _disk_total _disk_used
  _cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs | cut -c1-30 || echo "N/D")
  _cores=$(nproc 2>/dev/null || echo "?")
  _ram_total=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "?")
  _ram_used=$(free -h 2>/dev/null | awk '/^Mem:/{print $3}' || echo "?")
  _ram_free=$(free -h 2>/dev/null | awk '/^Mem:/{print $4}' || echo "?")
  _disk_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
  _disk_used=$(df -h / 2>/dev/null | awk 'NR==2{print $3}' || echo "?")

  printf "${DIM}  CPU: ${NC}${_cpu} ${DIM}(${_cores}c)  RAM: ${NC}${_ram_used}${DIM}/${_ram_free}/${_ram_total}  Disco: ${NC}${_disk_used}${DIM}/${_disk_total}  —  Pressione ${YELLOW}Ctrl+C${DIM} para fechar${NC}\n"
  printf "${GREEN}${DLINE}${NC}\n"

  # barra de progresso — aparece apenas durante instalação (quando _STEP_TOTAL > 0)
  _render_progress_bar
}
