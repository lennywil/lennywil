#!/bin/bash
# -*- coding: utf-8 -*-

# Backup-Verzeichnis
backup_dir="/backup"

# Quellverzeichnis
source_dir="/home"

# Funktion zum Senden von Fehlermeldungen an die Konsole
send_error() {
    local error_message=$1
    echo "$error_message"
}

# Überprüfe, ob rsync installiert ist und installiere es, falls es nicht vorhanden ist
if ! command -v rsync &> /dev/null; then
    error_message="rsync konnte nicht gefunden werden. Installiere rsync..."
    echo "$error_message"
    send_error "$error_message"
    sudo apt-get install -y rsync
    if [[ $? -ne 0 ]]; then
        error_message="Fehler beim Installieren von rsync."
        echo "$error_message"
        send_error "$error_message"
        exit 1
    fi
fi

# Erstelle das Backup-Verzeichnis, falls es nicht existiert
if [[ ! -d "$backup_dir" ]]; then
    mkdir -p "$backup_dir"
    if [[ $? -ne 0 ]]; then
        error_message="Fehler beim Erstellen des Backup-Verzeichnisses."
        echo "$error_message"
        send_error "$error_message"
        exit 1
    fi
fi

# Zähle die Anzahl der vorhandenen Backups und erhöhe die Backup-Nummer um 1
backup_count=$(ls "$backup_dir" | wc -l)
backup_number=$((backup_count + 1))

# Der Name des Backup-Verzeichnisses
backup_name="backup_$backup_number"

# Startzeit des Backups
start_time=$(date +%s)

# Erstelle das Backup und zeige den Fortschritt an
echo "Erstelle Backup $backup_name..."
rsync -a --info=progress2 "$source_dir" "$backup_dir/$backup_name"
if [[ $? -ne 0 ]]; then
    error_message="**Backup fehlgeschlagen**"
    echo "$error_message"
    send_error "$error_message"
    exit 1
fi

# Endzeit des Backups und Berechnung der Dauer
end_time=$(date +%s)
duration=$((end_time - start_time))

# Zähle die Anzahl der Dateien im Backup und berechne die Größe
file_count=$(find "$backup_dir/$backup_name" -type f | wc -l)
backup_size=$(du -sh "$backup_dir/$backup_name" | awk '{print $1}')

# Ausgabe der Backup-Informationen
echo "Backup $backup_name erstellt."
echo "Dauer: $duration Sekunden"
echo "Anzahl der Dateien: $file_count"
echo "Größe: $backup_size"

# Server IP ermitteln
server_ip=$(hostname -I | awk '{print $1}')

# Überprüfe, ob cron installiert ist und läuft
if ! command -v cron &> /dev/null || ! service cron status &> /dev/null; then
    # Versuche cron zu installieren und zu starten
    echo "Cron ist nicht installiert oder läuft nicht. Versuche, cron zu installieren und zu starten..."
    sudo apt-get install -y cron
    sudo service cron start
    if [[ $? -ne 0 ]]; then
        error_message="Fehler beim Installieren oder Starten von cron."
        echo "$error_message"
        send_error "$error_message"
        exit 1
    fi
fi

# Füge das Skript zur Crontab hinzu, falls es noch nicht vorhanden ist
cron_job="0 0 * * * /backup.sh"
(crontab -l 2>/dev/null | grep -q "$cron_job") || (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
if [[ $? -ne 0 ]]; then
    error_message="**Fehler bei der Crontab-Einstellung**"
    echo "$error_message"
    send_error "$error_message"
    exit 1
fi

# Überprüfe, ob die Anzahl der Backups 100 erreicht hat
if [[ $backup_count -ge 100 ]]; then
    # Finde den ältesten Ordner (außer dem neuesten) und lösche ihn
    oldest_backup=$(ls -tr "$backup_dir" | head -n 1)
    rm -rf "$backup_dir/$oldest_backup"
    if [[ $? -ne 0 ]]; then
        error_message="**Fehler bei der Löschung des ältesten Backups**"
        echo "$error_message"
        send_error "$error_message"
        exit 1
    fi
    echo "Das älteste Backup wurde gelöscht, da die maximale Anzahl von 100 Backups erreicht wurde."
fi
