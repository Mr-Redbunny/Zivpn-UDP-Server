#!/bin/bash

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# File Database
DB_FILE="/root/users.json"
SERVICE_NAME="zivpn.service"

if [ ! -f "$DB_FILE" ]; then
    echo "[]" > "$DB_FILE"
fi

# Fungsi untuk memeriksa dan menampilkan status server
check_server_status() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        SERVER_STATUS="${GREEN}AKTIF (Berjalan)${NC}"
    else
        SERVER_STATUS="${RED}TIDAK AKTIF (Berhenti)${NC}"
    fi
}

# --- Fungsi Kontrol Server ---
control_server() {
    ACTION=$1
    clear
    echo -e "${YELLOW}Sedang mencoba untuk ${ACTION} server...${NC}"

    # Menjalankan perintah dengan sudo karena skrip mungkin tidak dijalankan sebagai root
    sudo systemctl "$ACTION" "$SERVICE_NAME"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Server berhasil di-${ACTION}.${NC}"
    else
        echo -e "${RED}Gagal untuk ${ACTION} server. Coba periksa log dengan 'journalctl -u ${SERVICE_NAME}'.${NC}"
    fi

    read -p "Tekan [Enter] untuk kembali..."
}

# Fungsi untuk menambah pengguna baru
add_user() {
    clear
    echo -e "${CYAN}----- Tambah Pengguna Baru -----${NC}"

    while true; do
        read -p "Masukkan nama pengguna: " username
        if [[ -z "$username" ]]; then
            echo -e "${RED}Nama pengguna tidak boleh kosong.${NC}"
        elif jq -e --arg user "$username" '.[] | select(.username == $user)' "$DB_FILE" > /dev/null; then
            echo -e "${RED}Nama pengguna \"$username\" sudah ada. Silakan pilih nama lain.${NC}"
        else
            echo -e "${GREEN}Nama pengguna \"$username\" tersedia.${NC}"
            break
        fi
    done

    read -sp "Masukkan kata sandi (akan tersembunyi): " password
    echo ""
    if [[ -z "$password" ]]; then
        echo -e "${RED}Kata sandi tidak boleh kosong. Proses dibatalkan.${NC}"
        read -p "Tekan [Enter] untuk kembali..."
        return
    fi
    echo -e "${GREEN}Kata sandi telah diatur.${NC}"

    ip_limit=1

    while true; do
        read -p "Masukkan masa berlaku (dalam hari, contoh: 30): " days_valid
        if [[ "$days_valid" =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo -e "${RED}Harap masukkan jumlah hari yang valid.${NC}"
        fi
    done

    expiration_timestamp=$(date +%s -d "+$days_valid days")
    expiration_date=$(date -d "@$expiration_timestamp" '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}Akun akan aktif selama $days_valid hari.${NC}"

    new_user=$(jq -n --arg user "$username" --arg pass "$password" --arg limit "$ip_limit" --arg exp_ts "$expiration_timestamp" \
                  '{username: $user, password: $pass, ip_limit: ($limit|tonumber), expiration_timestamp: ($exp_ts|tonumber)}')

    jq ". += [$new_user]" "$DB_FILE" > "${DB_FILE}.tmp" && mv "${DB_FILE}.tmp" "$DB_FILE"

    echo -e "${CYAN}=========================================${NC}"
    echo -e "${GREEN}Pengguna \"$username\" berhasil ditambahkan!${NC}"
    echo "Akun akan kedaluwarsa pada: $expiration_date"
    echo -e "${CYAN}=========================================${NC}"
    read -p "Tekan [Enter] untuk kembali ke menu utama..."
}

# Fungsi untuk menampilkan semua pengguna
list_users() {
    clear
    echo -e "${CYAN}----- Daftar Pengguna Aktif -----${NC}"

    if ! jq -e '. | length > 0' "$DB_FILE" > /dev/null; then
        echo "Belum ada pengguna yang terdaftar."
    else
        printf "%-5s | %-15s | %-20s | %-20s\n" "No" "Username" "Password" "Kedaluwarsa"
        echo "----------------------------------------------------------------------"

        jq -c '.[]' "$DB_FILE" |
        i=0
        while IFS= read -r user_json; do
            ((i++))
            username=$(jq -r '.username' <<< "$user_json")
            password=$(jq -r '.password' <<< "$user_json")
            exp_ts=$(jq -r '.expiration_timestamp' <<< "$user_json")
            exp_date=$(date -d "@$exp_ts" '+%Y-%m-%d %H:%M:%S')

            printf "%-5s | %-15s | %-20s | %-20s\n" "$i" "$username" "$password" "$exp_date"
        done
        echo "----------------------------------------------------------------------"
    fi

    read -p "Tekan [Enter] untuk kembali ke menu utama..."
}

# Fungsi untuk menghapus pengguna
delete_user() {
    clear
    echo -e "${CYAN}----- Hapus Pengguna -----${NC}"

    if ! jq -e '. | length > 0' "$DB_FILE" > /dev/null; then
        echo "Tidak ada pengguna untuk dihapus."
        read -p "Tekan [Enter] untuk kembali..."
        return
    fi

    jq -r '.[] | .username' "$DB_FILE" | nl -w2 -s'. '
    echo ""

    read -p "Masukkan nomor pengguna yang ingin dihapus (atau 'batal'): " user_num

    if [[ "$user_num" == "batal" ]]; then
        return
    fi

    if ! [[ "$user_num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Input tidak valid.${NC}"
        sleep 2
        delete_user
        return
    fi

    user_to_delete=$(jq -r --argjson index "$((user_num - 1))" '.[$index].username' "$DB_FILE")

    if [[ -z "$user_to_delete" ]]; then
        echo -e "${RED}Nomor pengguna tidak ditemukan.${NC}"
        sleep 2
        delete_user
        return
    fi

    read -p "Apakah Anda yakin ingin menghapus pengguna \"$user_to_delete\"? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        jq --arg user "$user_to_delete" 'del(.[] | select(.username == $user))' "$DB_FILE" > "${DB_FILE}.tmp" && mv "${DB_FILE}.tmp" "$DB_FILE"
        echo -e "${GREEN}Pengguna \"$user_to_delete\" telah berhasil dihapus.${NC}"
    else
        echo "Penghapusan dibatalkan."
    fi

    read -p "Tekan [Enter] untuk kembali..."
}

# Fungsi untuk memperbarui server
update_server() {
    clear
    echo -e "${YELLOW}Fungsi ini akan menjalankan kembali skrip instalasi untuk memperbarui biner server.${NC}"
    echo "Data pengguna dan skrip manajemen Anda akan tetap aman."
    read -p "Apakah Anda ingin melanjutkan? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [ -f "/root/zi.sh" ]; then
            bash /root/zi.sh
        else
            wget -O /root/zi.sh https://raw.githubusercontent.com/Mr-Redbunny/Zivpn-UDP-Server/main/zi.sh && sudo chmod +x /root/zi.sh && sudo /root/zi.sh
        fi
        echo -e "${GREEN}Proses pembaruan selesai.${NC}"
    else
        echo "Pembaruan dibatalkan."
    fi
    read -p "Tekan [Enter] untuk kembali..."
}

# Fungsi untuk menghapus instalan server
uninstall_server() {
    clear
    echo -e "${RED}PERINGATAN: Opsi ini akan menghapus instalan ZIVPN dan SEMUA komponen Redbunny Manager.${NC}"
    echo "Ini termasuk semua data pengguna, skrip menu, dan otomatisasi."
    read -p "Apakah Anda benar-benar yakin ingin melanjutkan? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        read -p "Konfirmasi terakhir. Ketik 'HAPUS' untuk melanjutkan: " final_confirm
        if [[ "$final_confirm" == "HAPUS" ]]; then
            echo "Menjalankan proses uninstall..."
            (crontab -l | grep -v "auth.sh" | crontab -)
            if [ -f "/root/uninstall.sh" ]; then
                bash /root/uninstall.sh
            else
                wget -O /root/uninstall.sh https://raw.githubusercontent.com/Mr-Redbunny/Zivpn-UDP-Server/main/uninstall.sh && sudo chmod +x /root/uninstall.sh && sudo /root/uninstall.sh
            fi
            rm -f /root/users.json
            rm -f /usr/local/bin/rb-menu
            rm -f /usr/local/bin/auth.sh
            echo -e "${GREEN}Semua komponen telah dihapus. Terima kasih.${NC}"
            exit 0
        else
            echo "Konfirmasi salah. Penghapusan dibatalkan."
        fi
    else
        echo "Penghapusan dibatalkan."
    fi
    read -p "Tekan [Enter] untuk kembali..."
}

# Fungsi untuk menampilkan menu utama
show_main_menu() {
    check_server_status
    clear
    echo -e "${RED}"
    echo "      (\_/)"
    echo "     (='.'=)"
    echo "     (\")_(\")"
    echo -e "${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo -e "      ${YELLOW}Redbunny UDP Server Manager${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo -e "  Status Server: ${SERVER_STATUS}"
    echo ""
    echo "  --- Manajemen Pengguna ---"
    echo "  1. Tambah Pengguna Baru"
    echo "  2. Hapus Pengguna"
    echo "  3. Tampilkan Semua Pengguna"
    echo ""
    echo "  --- Manajemen Server ---"
    echo "  4. Mulai Server"
    echo "  5. Hentikan Server"
    echo "  6. Mulai Ulang Server (Restart)"
    echo "  7. Perbarui Server"
    echo "  8. Hapus Instalan Server"
    echo ""
    echo "  ---"
    echo "  9. Keluar"
    echo ""
    echo -e "${CYAN}=========================================${NC}"
}

# Loop menu utama
while true; do
    show_main_menu
    read -p "Masukkan pilihan Anda [1-9]: " choice
    case $choice in
        1) add_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) control_server "start" ;;
        5) control_server "stop" ;;
        6) control_server "restart" ;;
        7) update_server ;;
        8) uninstall_server ;;
        9) echo "Terima kasih telah menggunakan Redbunny Server Manager!" && exit 0 ;;
        *) echo -e "${RED}Pilihan tidak valid. Silakan coba lagi.${NC}" && sleep 2 ;;
    esac
done
