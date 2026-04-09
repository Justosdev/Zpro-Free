#!/bin/bash
#
# Print banner art.

#######################################
# Print a board.
# Globals:
#   GREEN  DIM  NC  LINE  DLINE
# Arguments:
#   None
#######################################
print_banner() {
  clear
  printf "\n"
  printf "${GREEN}${DLINE}${NC}\n"
  printf "${GREEN}"
  printf "  █████████      ███████         █████████\n"
  printf "        ███      ███    ██       ███      \n"
  printf "      ███        ███    ███      ███      \n"
  printf "    ███          ███    ███      ███  ████\n"
  printf "  ███            ███    ██       ███    ██\n"
  printf "  █████████      ███████         █████████ FREE\n"
  printf "${NC}"
  printf "\n"
  printf "${DIM}  Plataforma de Multiatendimento — Z-PRO FREE${NC}\n"
  printf "${GREEN}${LINE}${NC}\n"
  # info de hardware
  local _cpu _cores _ram_total _ram_used _ram_free _disk_total _disk_used
  _cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "N/D")
  _cores=$(nproc 2>/dev/null || echo "?")
  _ram_total=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "?")
  _ram_used=$(free -h 2>/dev/null | awk '/^Mem:/{print $3}' || echo "?")
  _ram_free=$(free -h 2>/dev/null | awk '/^Mem:/{print $4}' || echo "?")
  _disk_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
  _disk_used=$(df -h / 2>/dev/null | awk 'NR==2{print $3}' || echo "?")

  printf "${DIM}  CPU : ${NC}${_cpu} ${DIM}(${_cores} cores)${NC}\n"
  printf "${DIM}  RAM : ${NC}${_ram_used} ${DIM}usado / ${NC}${_ram_free} ${DIM}livre / ${NC}${_ram_total} ${DIM}total${NC}\n"
  printf "${DIM}  Disco: ${NC}${_disk_used} ${DIM}usado / ${NC}${_disk_total} ${DIM}total${NC}\n"
  printf "${GREEN}${LINE}${NC}\n"
  printf "${DIM}  https://github.com/Justosdev/Zpro-Free${NC}\n"
  printf "${DIM}  Solução sob licença MIT${NC}\n"
  printf "${DIM}  Pressione ${YELLOW}Ctrl+C${NC}${DIM} para fechar o instalador.${NC}\n"
  printf "${GREEN}${DLINE}${NC}\n"
  printf "\n"
}
