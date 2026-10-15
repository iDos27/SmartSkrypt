#!/bin/bash

BLUE='\033[1;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[31m'
NC='\033[0m'

show_usage() {
    echo -e "${YELLOW}UŻYCIE:${NC}"
    echo -e "  $0 -f <plik_logu> [-s <data_od>] [-e <data_do>]"
    echo -e ""
    echo -e "${YELLOW}OPCJE:${NC}"
    echo -e "  ${GREEN}-f <ścieżka>${NC}   Ścieżka do pliku logu Apache/Nginx (wymagane)"
    echo -e "  ${GREEN}-s <data>${NC}      Data początkowa (opcjonalnie)"
    echo -e "  ${GREEN}-e <data>${NC}      Data końcowa (opcjonalnie)"
    echo -e "  ${GREEN}-h${NC}             Wyświetla tę pomoc"
    echo -e ""
    echo -e "${YELLOW}PRZYKŁADOWE FORMATY DATY:${NC}"
    echo -e "  • 'YYYY-MM-DD'           np. -s '2005-12-04'"
    echo -e "  • 'YYYY.MM.DD'           np. -s '2005.12.04'"
    echo -e "  • 'YYYY-MM-DD HH:MM:SS'  np. -s '2005-12-04 10:00:00'"
    echo -e "  • 'DD/Mon/YYYY:HH:MM:SS' np. -s '04/Dec/2005:10:00:00'"
    echo -e ""
    echo -e "${YELLOW}PRZYKŁADY WYWOŁANIA:${NC}"
    echo -e "  $0 -f Apache_2k.log"
    echo -e "  $0 -f Apache_2k.log -s 2005-12-04"
    echo -e "  $0 -f Apache_2k.log -s 2005.12.04 -e 2005.12.05"
    echo -e "  $0 -f Apache_2k.log -s '2005-12-04 08:00:00' -e '2005-12-04 12:00:00'"
}

parse_date_to_ts() {
    local input="$1"
    local mode="$2"

    input=$(echo "$input" | sed -E 's/^([0-9]{4})\.([0-9]{2})\.([0-9]{2})/\1-\2-\3/')

    if [[ "$input" =~ ^([0-9]{2})\.([0-9]{2})$ ]]; then
        input="$(date +%Y)-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}"
    fi

    if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        if [ "$mode" == "start" ]; then
            input="$input 00:00:00"
        else
            input="$input 23:59:59"
        fi
    fi

    date -d "$input" +"%Y%m%d%H%M%S" 2>/dev/null
}

LOG_FILE=""
START_RAW=""
END_RAW=""

while getopts ":f:s:e:h" opt; do
    case "$opt" in
        f) LOG_FILE="$OPTARG" ;;
        s) START_RAW="$OPTARG" ;;
        e) END_RAW="$OPTARG" ;;
        h) show_usage; exit 0 ;;
        :) 
           echo -e "${RED}[!] BŁĄD: Opcja -$OPTARG wymaga podania wartości.${NC}\n"
           show_usage
           exit 1
           ;;
        \?) 
           echo -e "${RED}[!] BŁĄD: Nieznana flaga -$OPTARG.${NC}\n"
           show_usage
           exit 1
           ;;
    esac
done

if [ -z "$LOG_FILE" ]; then
    echo -e "${RED}[!] BŁĄD: Nie wskazano pliku logów flagą -f.${NC}\n"
    show_usage
    exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}[!] BŁĄD: Wskazany plik '$LOG_FILE' nie istnieje.${NC}"
    exit 1
fi

START_TS=""
END_TS=""

if [ -n "$START_RAW" ]; then
    START_TS=$(parse_date_to_ts "$START_RAW" "start")
    if [ -z "$START_TS" ]; then
        echo -e "${RED}[!] BŁĄD: Niepoprawny format daty początkowej (-s '$START_RAW').${NC}\n"
        show_usage
        exit 1
    fi
fi

if [ -n "$END_RAW" ]; then
    END_TS=$(parse_date_to_ts "$END_RAW" "end")
    if [ -z "$END_TS" ]; then
        echo -e "${RED}[!] BŁĄD: Niepoprawny format daty końcowej (-e '$END_RAW').${NC}\n"
        show_usage
        exit 1
    fi
fi

TEMP_LOG=$(mktemp)
trap 'rm -f "$TEMP_LOG"' EXIT

awk -v from="$START_TS" -v to="$END_TS" '
BEGIN {
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " ")
    for (i = 1; i <= 12; i++) month[m[i]] = sprintf("%02d", i)
}
{
    match($4, /^\[?([0-9]{2})\/([A-Za-z]{3})\/([0-9]{4}):([0-9]{2}):([0-9]{2}):([0-9]{2})/, d)
    if (d[1] != "") {
        ts = d[3] month[d[2]] d[1] d[4] d[5] d[6]
        if (from != "" && ts < from) next
        if (to != "" && ts > to) next
        print $0
    }
}' "$LOG_FILE" > "$TEMP_LOG"

if [ ! -s "$TEMP_LOG" ]; then
    echo -e "${YELLOW}[!] Brak wpisów w wybranym przedziale czasowym.${NC}"
    exit 0
fi

echo -e "${BLUE}================================================================${NC}"
echo -e "${RED}       ANALIZA: $LOG_FILE "

FIRST_DATE=$(head -n 1 "$TEMP_LOG" | awk '{print $4, $5}' | tr -d '[]')
LAST_DATE=$(tail -n 1 "$TEMP_LOG" | awk '{print $4, $5}' | tr -d '[]')

echo -e "${NC} Dane od: ${GREEN}${FIRST_DATE:-Brak danych}${NC}"
echo -e "${NC} Dane do: ${GREEN}${LAST_DATE:-Brak danych}${NC}"
echo -e ""

echo -e "${BLUE}==== ${YELLOW} Top 10 adresów IP ${BLUE}====${NC}"
awk '{print $1}' "$TEMP_LOG" | sort | uniq -c | sort -nr | head -n 10
echo -e ""

echo -e "${BLUE}==== ${YELLOW} Top 10 Endpoint ${BLUE}====${NC}"
awk '{print $7}' "$TEMP_LOG" | cut -d'?' -f1 | sort | uniq -c | sort -nr | head -n 10
echo -e ""

echo -e "${BLUE}==== ${YELLOW} Top 10 User-Agent ${BLUE}====${NC}"
awk -F\" '{print $6}' "$TEMP_LOG" | sort | uniq -c | sort -nr | head -n 10
echo -e ""

echo -e "${BLUE}==== ${YELLOW} Kody odpowiedzi HTTP ${BLUE}====${NC}"
awk '{print $9}' "$TEMP_LOG" | sort | uniq -c | sort -nr
echo -e ""