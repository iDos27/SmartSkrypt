#!/bin/bash

BLUE='\033[1;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[31m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${YELLOW}Użycie: $0 plik_z_domenami.txt${NC}"
    exit 1
fi

sed 's/[[:space:]]//g' "$1" | while read -r domena; do
    [[ -z "$domena" ]] && continue

    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}                    ANALIZA: $domena ${NC}"
    echo -e "${BLUE}================================================================${NC}"


    whois_data=$(whois "$domena")

    echo -e "${YELLOW}[1] RAPORT WHOIS (Status / Rejestrator / Daty):${NC}"
    
    status_raw=$(echo "$whois_data" | grep -Ei "status:|state:|registration status:" | head -n 1 | sed 's/.*: //' | xargs)
    
    echo -n "Status:      "
    if [ -n "$status_raw" ]; then
        echo -e "${GREEN}$status_raw${NC}"
    elif echo "$whois_data" | grep -qi "renewal date:\|expiration date:\|expires:"; then
        echo -e "${GREEN}Registered (Active)${NC}"
    elif echo "$whois_data" | grep -qi "no data found\|brak informacji\|No entries found\|No information\|No match for domain"; then
        echo -e "${RED}Wolna / Niezarejestrowana${NC}"
    else
        echo -e "${YELLOW}Nieznany (Sprawdź ręcznie)${NC}"
    fi
    
    echo -n "Rejestrator: "
    reg_info=$(echo "$whois_data" | grep -EiA 1 "registrar:|rejestrator:" | grep -vEi "registrar:|rejestrator:|--" | head -n 1 | xargs)
    if [ -z "$reg_info" ]; then echo "Brak danych"; else echo "$reg_info"; fi

    echo "$whois_data" | grep -Ei "created:|creation date:|expires:|expiration date:|renewal date:" | sed 's/^[ \t]*//'

    # 2. Rekordy A
    echo -e "\n${YELLOW}[2] REKORDY A (Strona WWW):${NC}"
    echo -n "Glowna (@):   "
    dig a "$domena" +short | xargs echo -n
    echo -e "\nSubdomena www: "
    dig a "www.$domena" +short | xargs echo -n

# 3. Rekordy MX i weryfikacja IP serwera pocztowego
    echo -e "\n\n${YELLOW}[3] REKORDY MX (Poczta):${NC}"
    mx_records=$(dig mx "$domena" +short | sort -n)
    
    if [ -z "$mx_records" ]; then
        echo -e "${RED}Brak rekordów MX${NC}"
    else
        echo "$mx_records" | while read -r priority server; do
            server_clean=${server%.}
            srv_ip=$(dig a "$server_clean" +short | tail -n1)
            
            echo -n "Serwer: $server_clean (priorytet $priority) -> IP: "
            
            if [ -z "$srv_ip" ]; then
                echo -e "${RED}Nie udało się pobrać IP${NC}"
            else
                echo -n "$srv_ip"
                if [[ $srv_ip =~ ^91.211.220.\. ]]; then
                    echo -e " ${GREEN}(UWAGA: Startuje od 91.211.220.0)${NC}"
                elif [[ $srv_ip =~ ^91.211.221.\. ]]; then
                    echo -e " ${GREEN}(UWAGA: Startuje od 91.211.221.0)${NC}"
                elif [[ $srv_ip =~ ^91.211.222.\. ]]; then
                    echo -e " ${GREEN}(UWAGA: Startuje od 91.211.222.0)${NC}"
                elif [[ $srv_ip =~ ^193.93.88.\. ]]; then
                    echo -e " ${GREEN}(UWAGA: Startuje od 193.93.88.0)${NC}"
                elif [[ $srv_ip =~ ^193.93.89.\. ]]; then
                    echo -e " ${YELLOW}(UWAGA SPRAWDZ CZY OST.OKTET > 64: 193.93.89.64)${NC}"
                else
                    echo -e " ${RED}(MOZNA ODPARK: Startuje od ${srv_ip%%.*}.)${NC}"
                fi
            fi
        done
    fi

    # 4. DNS
    echo -e "\n\n${YELLOW}[4] SERWERY DNS (Delegacja):${NC}"
    dns_info=$(dig ns "$domena" +short)
    if [ -z "$dns_info" ]; then
        echo "Brak rekordów NS (sprawdź czy domena nie wygasła)"
    else
        echo "$dns_info"
    fi

    # Weryfikacja Smarthost
    if echo "$dns_info" | grep -qi "smarthost"; then
        echo -e "\n${GREEN}>>> INFO: Ta domena korzysta z DNS Smarthost.pl${NC}"
    else
        echo -e "\n${RED}>>> INFO: Ta domena NIE KORZYSTA z DNS Smarthost.pl${NC}"
    fi

    echo -e "\n"
done < <(sed 's/[[:space:]]//g' "$1")