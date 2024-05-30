#!/bin/bash

# Funktion zur Behandlung von Fehlern
handle_error() {
  echo "Ein Fehler ist aufgetreten: $1" >&2
  exit 1
}

# Funktion zur Prüfung des letzten Befehls auf Fehler
check_error() {
  if [[ "$?" -ne 0 ]]; then
    handle_error "Der vorherige Befehl war nicht erfolgreich."
  fi
}

# Paketmanager aktualisieren und benötigte Pakete installieren
sudo apt update || handle_error "Aktualisierung des Paketmanagers fehlgeschlagen."
sudo apt install -y wget curl jq screen net-tools openjdk-17-jdk openjdk-8-jdk whiptail || handle_error "Paketinstallation fehlgeschlagen."
check_error

# Startzeitpunkt erfassen
start_time=$(date +%s)

# Liste der Minecraft-Versionen, sortiert von klein zu groß
versions=(
  "1.20.4" "1.20.2" "1.20.1" "1.20" "1.19.4"
  "1.19.3" "1.19.2" "1.19.1" "1.19" "1.18.2" "1.18.1" "1.18"
  "1.17.1" "1.17" "1.16.5" "1.16.4" "1.16.3" "1.16.2" "1.16.1"
  "1.15.2" "1.15.1" "1.15" "1.14.4" "1.14.3" "1.14.2" "1.14.1"
  "1.14" "1.13.2" "1.13.1" "1.13" "1.13-pre7" "1.12.2" "1.12.1"
  "1.12" "1.11.2" "1.10.2" "1.9.4" "1.8.8"
)

# Basis-URL für den Download
base_url="https://papermc.io/api/v2/projects/paper/versions"

# Erzeugen der Optionsliste für das Menü
options=()
for i in "${!versions[@]}"; do
  options+=("$i" "${versions[$i]}")
done

# Anzeigen des Menüs und Erfassen der Auswahl
version_index=$(whiptail --title "Minecraft-Version auswählen" --menu "Wählen Sie eine Minecraft-Version aus:" 20 78 10 "${options[@]}" 3>&1 1>&2 2>&3)
check_error
version=${versions[$version_index]}

# Abfrage der Anzahl der zu erstellenden Server
server_count=$(whiptail --title "Anzahl der Server" --inputbox "Geben Sie die Anzahl der zu erstellenden Server ein:" 10 60 3>&1 1>&2 2>&3)
check_error

# Abfrage der Menge des zuzuweisenden RAMs
ram=$(whiptail --title "RAM zuweisen" --inputbox "Geben Sie die Menge des zuzuweisenden RAMs in GB ein (z.B. 2G):" 10 60 3>&1 1>&2 2>&3)
check_error

# Basisport für den ersten Server
base_port=25565

# Ordnerzähler für nummerierte Ordner
folder_counter=1

# Starten aller Server in einem screen mit unterschiedlichem Namen
for ((i=1; i<=server_count; i++)); do
  folder="/home/server_$folder_counter"
  while [ -d "$folder" ]; do
    folder_counter=$((folder_counter+1))
    folder="/home/server_$folder_counter"
  done
  mkdir -p "$folder"
  check_error

  # Holen der neuesten Build-Nummer für diese Version
  build=$(curl -s "$base_url/$version" | jq -r '.builds[-1]')
  check_error

  # URL für den Download des Servers
  download_url="$base_url/$version/builds/$build/downloads/paper-$version-$build.jar"

  # Herunterladen des Servers
  wget -P "$folder" "$download_url"
  check_error

  # Akzeptieren der EULA
  echo "eula=true" > "$folder/eula.txt"

  # Berechnen des Ports für diesen Server
  port=$((base_port + folder_counter - 1))

  # Erstellen des Startskripts
  cat << EOF > "$folder/start.sh"
#!/bin/bash
cd "$folder"
screen -dmS server_$folder_counter java -Xmx$ram -Xms$ram -jar paper-$version-$build.jar --port $port nogui
EOF
  chmod +x "$folder/start.sh"

  # Starten des Servers
  bash "$folder/start.sh" &
  check_error
  echo "Der Server $folder_counter wurde erfolgreich erstellt und gestartet."

  folder_counter=$((folder_counter + 1)) # Erhöhe den Zähler für den nächsten Ordner
done

# Erfolgsmeldung
echo "Alle Server wurden erfolgreich erstellt und gestartet."
