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

# Basis-URL für den Download von Paper, Spigot, Bukkit und Mojang
paper_base_url="https://papermc.io/api/v2/projects/paper/versions"
spigot_base_url="https://download.getbukkit.org/spigot"
bukkit_base_url="https://download.getbukkit.org/craftbukkit"
mojang_base_url="https://launcher.mojang.com/v1/objects"

# Abfrage des Servertyps (Paper, Spigot, Bukkit oder Mojang)
server_type=$(whiptail --title "Servertyp auswählen" --menu "Wählen Sie den Servertyp aus:" 20 78 10 \
  "1" "Paper" \
  "2" "Spigot" \
  "3" "Bukkit" \
  "4" "Mojang" 3>&1 1>&2 2>&3)
check_error

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

# Abfrage des Ports
port=$(whiptail --title "Port auswählen" --inputbox "Geben Sie den Port ein, den Sie für den Server verwenden möchten:" 10 60 3>&1 1>&2 2>&3)
check_error

# Basisport für den ersten Server
base_port=25565

# Ordnerzähler für nummerierte Ordner
folder_counter=1

# Funktion zum Herunterladen der Mojang JAR-Datei
download_mojang_jar() {
  local version=$1
  local folder=$2

  # Abfragen der URL der JAR-Datei
  local mojang_meta_url="https://launchermeta.mojang.com/mc/game/version_manifest.json"
  local version_json=$(curl -s "$mojang_meta_url" | jq -r --arg version "$version" '.versions[] | select(.id == $version) | .url')
  check_error

  local jar_url=$(curl -s "$version_json" | jq -r '.downloads.server.url')
  check_error

  wget -P "$folder" "$jar_url" -O "$folder/server.jar"
  check_error
}

# Starten aller Server in einem screen mit unterschiedlichem Namen
for ((i=1; i<=server_count; i++)); do
  # Ordnername basierend auf dem Servertyp
  if [[ "$server_type" -eq 1 ]]; then
    server_type_name="Paper"
  elif [[ "$server_type" -eq 2 ]]; then
    server_type_name="Spigot"
  elif [[ "$server_type" -eq 3 ]]; then
    server_type_name="Bukkit"
  else
    server_type_name="Mojang"
  fi

  folder="/home/server_${folder_counter}_${server_type_name}"
  while [ -d "$folder" ]; do
    folder_counter=$((folder_counter+1))
    folder="/home/server_${folder_counter}_${server_type_name}"
  done
  mkdir -p "$folder"
  check_error

  # URL für den Download des Servers
  if [[ "$server_type" -eq 1 ]]; then
    # Paper-Download
    build=$(curl -s "$paper_base_url/$version" | jq -r '.builds[-1]')
    check_error
    download_url="$paper_base_url/$version/builds/$build/downloads/paper-$version-$build.jar"
  elif [[ "$server_type" -eq 2 ]]; then
    # Spigot-Download
    download_url="$spigot_base_url/spigot-$version.jar"
  elif [[ "$server_type" -eq 3 ]]; then
    # Bukkit-Download
    download_url="$bukkit_base_url/craftbukkit-$version.jar"
  else
    # Mojang-Download
    download_mojang_jar "$version" "$folder"
    download_url="$folder/server.jar"
  fi

  # Herunterladen des Servers, falls nicht Mojang
  if [[ "$server_type" -ne 4 ]]; then
    wget -P "$folder" "$download_url"
    check_error
  fi

  # Akzeptieren der EULA
  echo "eula=true" > "$folder/eula.txt"

  # Berechnen des Ports für diesen Server
  server_port=$((port + folder_counter - 1))

  # Erstellen des Startskripts
  cat << EOF > "$folder/start.sh"
#!/bin/bash
cd "$folder"
screen -dmS server_${folder_counter}_${server_type_name} java -Xmx$ram -Xms$ram -jar $(basename "$download_url") --port $server_port nogui
EOF
  chmod +x "$folder/start.sh"

  # Starten des Servers
  bash "$folder/start.sh" &
  check_error
  echo "Der Server ${folder_counter}_${server_type_name} wurde erfolgreich erstellt und gestartet."

  folder_counter=$((folder_counter + 1)) # Erhöhe den Zähler für den nächsten Ordner
done

# Erfolgsmeldung
echo "Alle Server wurden erfolgreich erstellt und gestartet."

# Erstellen und Installieren des allstop.sh-Skripts
cat << 'EOF' > /root/allstop.sh
#!/bin/bash

# Alle Screen-Sitzungen auflisten
screen_list=$(screen -ls | grep -o '[0-9]*\.server_[0-9]*')

# Überprüfen ob Screen-Sitzungen vorhanden sind
if [ -z "$screen_list" ]; then
  echo "Keine Screen-Sitzungen gefunden."
  exit 0
fi

# Alle Screen-Sitzungen schließen
for session in $screen_list; do
  echo "Schließe Screen-Sitzung: $session"
  screen -S "$session" -X quit
done

echo "Alle Screen-Sitzungen wurden geschlossen."
EOF
check_error

# Machen des allstop.sh-Skripts ausführbar
sudo chmod +x /root/allstop.sh
check_error

# Erfolgsmeldung
echo "Das allstop.sh-Skript wurde erfolgreich erstellt und installiert."

# Erstellen und Installieren des allstart.sh-Skripts
cat << 'EOF' > /root/allstart.sh
#!/bin/bash

# Funktion zur Behandlung von Fehlern
handle_error() {
  echo "Ein Fehler ist aufgetreten: $1" >&2
  exit 1
}

# Überprüfen, ob Verzeichnisse existieren und Startskripte darin vorhanden sind
for dir in /home/server_*; do
  if [ -d "$dir" ]; then
    if [ -f "$dir/start.sh" ]; then
      # Ausführen des Startskripts
      bash "$dir/start.sh" &
      if [ "$?" -eq 0 ]; then
        echo "Der Server im Verzeichnis $dir wurde erfolgreich gestartet."
      else
        echo "Fehler beim Starten des Servers im Verzeichnis $dir."
      fi
    else
      echo "Startskript nicht gefunden im Verzeichnis $dir. Der Server wird übersprungen."
    fi
  else
    echo "Verzeichnis $dir nicht gefunden."
  fi
done

echo "Alle verfügbaren Server wurden gestartet."
EOF
check_error

# Machen des allstart.sh-Skripts ausführbar
sudo chmod +x /root/allstart.sh
check_error

# Erfolgsmeldung
echo "Das allstart.sh-Skript wurde erfolgreich erstellt und installiert."

# Erfolgsmeldung
echo "Alle Server wurden installiert."
