#!/bin/bash

BLUE='\033[1;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[31m'
NC='\033[0m'

if [ -z "$1" ] || [ ! -f "$1" ]; then
    echo -e "${RED}[!] BŁĄD: Podaj istniejący plik logu jako argument.${NC}"
    echo -e "Użycie: $0 <ścieżka_do_pliku>"
    exit 1
fi

LOG_FILE="$1"

echo -e "${BLUE}================================================================${NC}"
echo -e "${RED}       ANALIZA: $1 "
echo -e "${BLUE}================================================================${NC}"

echo -e ""
echo -e "${BLUE}================================================================${NC}"
FIRST_DATE=$(head -n 1 "$1" | awk '{print $4, $5}' | tr -d '[]')
LAST_DATE=$(tail -n 1 "$1" | awk '{print $4, $5}' | tr -d '[]')

echo -e "${NC} Dane od: ${GREEN}${FIRST_DATE:-Brak danych}${NC}"
echo -e "${NC} Dane do: ${GREEN}${LAST_DATE:-Brak danych}${NC}"
echo -e ""

echo -e "${BLUE}==== ${YELLOW} Top 10 adresów IP ${BLUE}====${NC}"
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -n 20
echo -e ""

echo -e "${BLUE}==== ${YELLOW} Top 10 Endpoint ${BLUE}====${NC}"
awk '{print $7}' "$LOG_FILE" | cut -d'?' -f1 | sort | uniq -c | sort -nr | head -n 25
echo -e ""

echo -e "${BLUE}==== ${YELLOW} Top 10 User-Agent ${BLUE}====${NC}"
awk -F\" '{print $6}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -n 10
echo -e ""

echo -e "${BLUE}==== ${YELLOW}Kody odpowiedzi HTTP ${BLUE}====${NC}"
awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -nr
echo -e ""