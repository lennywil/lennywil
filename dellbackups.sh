#!/bin/bash

# Backup-Verzeichnis
backup_dir="/backup"

# Funktion zum Löschen aller Backups
delete_all_backups() {
    if [[ ! -d $backup_dir ]]; then
        echo "Backup-Verzeichnis $backup_dir existiert nicht."
        exit 1
    fi

    backup_count=$(ls -1qA $backup_dir | wc -l)
    if [[ $backup_count -eq 0 ]]; then
        echo "Es gibt keine Backups im Verzeichnis $backup_dir zu löschen."
        exit 0
    fi

    # Berechne die Gesamtanzahl der Dateien und die Gesamtgröße der Backups
    file_count=$(find $backup_dir -type f | wc -l)
    total_size=$(du -sh $backup_dir | awk '{print $1}')

    # Ausgabe der Backup-Informationen vor dem Löschen
    echo "Anzahl der Backups: $backup_count"
    echo "Gesamtanzahl der Dateien: $file_count"
    echo "Gesamtgröße der Backups: $total_size"

    # Startzeit des Löschvorgangs
    start_time=$(date +%s)

    # Funktion zum Löschen einzelner Dateien und Verzeichnisse mit Fortschrittsanzeige
    delete_files_with_progress() {
        local total_files=$1
        local deleted_files=0
        local parallelism=4 # Number of parallel processes

        find $backup_dir -type f | xargs -P $parallelism -I {} sh -c '
            file="$1"
            backup_name=$(basename "$(dirname "$file")")
            rm -f "$file"
        ' _ {} | while read -r file backup_name; do
            ((deleted_files++))
            remaining_files=$((total_files - deleted_files))
            elapsed_time=$(( $(date +%s) - start_time ))
            if [ $deleted_files -gt 0 ]; then
                estimated_total_time=$(( elapsed_time * total_files / deleted_files ))
                estimated_remaining_time=$(( estimated_total_time - elapsed_time ))
            else
                estimated_remaining_time="Unbekannt"
            fi
            printf "\rGelöscht: %d / %d Dateien. Geschätzte verbleibende Zeit: %d Sekunden." "$deleted_files" "$total_files" "$estimated_remaining_time"
        done
    }

    echo "Lösche alle Backups im Verzeichnis $backup_dir..."
    delete_files_with_progress $file_count
    echo ""

    # Löschen der verbleibenden leeren Verzeichnisse
    find $backup_dir -type d -empty -delete

    if [[ $? -ne 0 ]]; then
        echo "Fehler beim Löschen der Backups im Verzeichnis $backup_dir."
        exit 1
    fi

    # Endzeit des Löschvorgangs und Berechnung der Dauer
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Ausgabe der Löschinformationen
    echo "Alle Backups wurden erfolgreich gelöscht."
    echo "Dauer: $duration Sekunden"
    echo "Anzahl der gelöschten Dateien: $file_count"
    echo "Gesamtgröße der gelöschten Backups: $total_size"
}

# Aufruf der Funktion zum Löschen aller Backups
delete_all_backups
