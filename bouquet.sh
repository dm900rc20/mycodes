#!/bin/sh
# -*- coding: utf-8 -*-


bq_name="userbouquet.skyicam_single.tv"
bq_datei_local="/etc/enigma2/${bq_name}"
bq_datei_online="https://raw.githubusercontent.com/dm900rc20/mycodes/main/${bq_name}"
tmp_datei="/tmp/${bq_name}"
log_datei="/tmp/bouquet.log"
log_datei_max=65000
bq_eintrag="#SERVICE 1:7:1:0:0:0:0:0:0:0:FROM BOUQUET \"$bq_name\" ORDER BY bouquet"


hilfe_nachricht="
VERWENDUNG:
    $0 install ......... um das BOUQUET in die Enigma2-Bouquet-Favoritenliste (/etc/enigma2/bouquets.tv) zu installieren.
    $0 entferne ........ um das BOUQUET in die Enigma2-Bouquet-Favoritenliste (/etc/enigma2/bouquets.tv) zu entfernen.
    $0 update .......... um das BOUQUET herunterzuladen und zu ersetzen, wenn eine neuere Version online ist.
"

bqLog() 
{
    if [ "${1:0:3}" = "===" ]; then
        logmsg="$1"
    else
        logmsg=$(echo "$1" | sed "s/^/`date '+%Y-%m-%d %H:%M:%S'` /")
    fi   
    #echo "$logmsg" > /dev/null                  ### Log wird deaktiviert
    echo "$logmsg" 2>&1 | tee -a $log_datei       ### Log wird aktiviert
    if [ -f "$log_datei" ] && [ $(wc -c <"$log_datei") -gt $log_datei_max ]; then sed -i -e '1,20d' "$log_datei"; fi
}

ist_standby() {
	[ "$(wget -q -O - http://127.0.0.1/web/powerstate | grep '</e2instandby>' | cut -f 1)" = "true" ]
}

not_standby() {
	[ "$(wget -q -O - http://127.0.0.1/web/powerstate | grep '</e2instandby>' | cut -f 1)" = "false" ]
}

standby() {
    wget -O - -q http://127.0.0.1/web/powerstate?newstate=5 >/dev/null 2>&1 > /dev/null 2>&1
    sleep 5
}

wakeup() {
    wget -O - -q http://127.0.0.1/web/powerstate?newstate=4 >/dev/null 2>&1 > /dev/null 2>&1
}

services_neu_laden() {
    wget -q -O - "http://127.0.0.1/web/servicelistreload?mode=0" > /dev/null 2>&1
    sleep 1
    wget -q -O - "http://127.0.0.1/web/servicelistreload?mode=4" > /dev/null 2>&1
    bqLog "Die Servicelisten wurden neu geladen (userbouquet.*.tv / .radio , userbouquets.tv , lamedb)"
}

update_austausch_userbouquet() {
    rm -f $tmp_datei
    
    if wget -q -O $tmp_datei "$bq_datei_online" > /dev/null 2>&1; then
        bqLog "$bq_datei_online wurde heruntergeladen"
    else
        bqLog "$bq_datei_online download fehlgeschlagen!"
    fi
    
    if [ -f "$tmp_datei" ] && diff -aw $tmp_datei $bq_datei_local > /dev/null 2>&1; then
        bqLog "$bq_datei_local wurde nicht aktualisiert (der Inhalt der Dateien ist derselbe)"
    else
        mv -f $tmp_datei $bq_datei_local
        bqLog "$bq_datei_local wurde aktualisiert"
    fi
}

case "$1" in
    install)
        if ! cat /etc/enigma2/bouquets.tv | grep -w "$bq_eintrag" > /dev/null; then
            sed -i "1 a $bq_eintrag" /etc/enigma2/bouquets.tv
            [ -f $bq_datei_local ] || touch $bq_datei_local 
            update_austausch_userbouquet
            services_neu_laden
        fi
        ;;
    entferne)
        sed -i "/$bq_eintrag/d" /etc/enigma2/bouquets.tv
        rm -f $bq_datei_local
        services_neu_laden
        ;;
    update)        
        if ist_standby; then
            update_austausch_userbouquet
            services_neu_laden
			
		elif not_standby; then
			echo "Box ist nicht im Standby Modus"
			read -p "Box im Standby versetzen? Enter oder j drücken, oder eine andere Taste zum beenden:" A
			if [ "$A" == "" -o "$A" == "j" -o "$A" == "J" -o "$A" == "y" -o "$A" == "Y" ];then
			echo "Box geht in Standy und aktualisiert $bq_datei_local"
			standby
			update_austausch_userbouquet
			services_neu_laden
			echo "Box aufwachen"
			wakeup
			else
			echo "Script wurde beendet"
			fi
        else
            bqLog "Sript wurde beendet"
        fi
        ;;
    *)
        echo "$hilfe_nachricht"
        ;;
esac

rm -f $tmp_datei
bqLog "---------------------------------------------------"

exit 0
