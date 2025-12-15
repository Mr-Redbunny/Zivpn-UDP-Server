#!/bin/bash

# Script ini bertanggung jawab untuk menyinkronkan database users.json
# dengan file konfigurasi zivpn yang sebenarnya. Ini dirancang untuk dijalankan
# secara berkala oleh cron.

# --- Konfigurasi Path Absolut ---
DB_FILE="/root/users.json"
CONFIG_FILE="/etc/zivpn/config.json"
SERVICE_NAME="zivpn.service"

# --- Fungsi Logging Sederhana ---
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# --- Pemeriksaan Awal ---
if [ ! -f "$DB_FILE" ]; then
    log "File database $DB_FILE tidak ditemukan. Keluar."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    log "File konfigurasi $CONFIG_FILE tidak ditemukan. Keluar."
    exit 1
fi

# --- Logika Utama ---

# Dapatkan timestamp saat ini
current_ts=$(date +%s)

# Langkah 1: Baca DB dan saring pengguna yang kedaluwarsa
# Menggunakan jq untuk memilih pengguna yang expiration_timestamp-nya lebih besar dari saat ini
# dan kemudian ekstrak hanya kata sandi mereka ke dalam sebuah array JSON.
valid_passwords_json=$(jq --argjson now "$current_ts" '[.[] | select(.expiration_timestamp > $now) | .password]' "$DB_FILE")

# Periksa apakah hasil jq valid
if [ -z "$valid_passwords_json" ]; then
    log "Gagal memproses file JSON atau tidak ada pengguna aktif. Menggunakan array kosong."
    valid_passwords_json="[]"
fi

# Langkah 2: Dapatkan daftar kata sandi saat ini dari config.json
current_passwords_json=$(jq '.auth.config' "$CONFIG_FILE")

# Periksa apakah hasil jq valid
if [ -z "$current_passwords_json" ]; then
    log "Gagal membaca konfigurasi saat ini dari $CONFIG_FILE. Proses dibatalkan untuk keamanan."
    exit 1
fi

# Langkah 3: Bandingkan konfigurasi saat ini dengan yang baru
# Untuk perbandingan yang andal, urutkan kedua array JSON.
sorted_current=$(echo "$current_passwords_json" | jq -S '.')
sorted_valid=$(echo "$valid_passwords_json" | jq -S '.')

if [ "$sorted_current" == "$sorted_valid" ]; then
    # Tidak ada perubahan, tidak perlu melakukan apa-apa.
    exit 0
else
    # Ada perubahan! Perbarui file konfigurasi.
    log "Perubahan terdeteksi. Memperbarui konfigurasi server..."

    # Buat salinan cadangan sebelum mengubah
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%s)"

    # Perbarui file config.json dengan daftar kata sandi yang baru
    if jq --argjson new_config "$valid_passwords_json" '.auth.config = $new_config' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"; then
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        log "File konfigurasi berhasil diperbarui."

        # Restart layanan untuk menerapkan perubahan
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            systemctl restart "$SERVICE_NAME"
            log "Layanan $SERVICE_NAME berhasil di-restart."
        else
            log "Layanan $SERVICE_NAME tidak aktif. Tidak melakukan restart."
        fi
    else
        log "Gagal memperbarui file konfigurasi sementara. Perubahan dibatalkan."
        rm -f "${CONFIG_FILE}.tmp"
        exit 1
    fi
fi

exit 0
