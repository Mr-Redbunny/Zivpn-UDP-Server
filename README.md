![ZIVPN](zivpn.png)

UDP server installation for ZIVPN Tunnel (SSH/DNS/UDP) VPN app.
<br>

>Server binary for Linux amd64 and arm.

#### Installation AMD
```
wget -O zi.sh https://raw.githubusercontent.com/Mr-Redbunny/Zivpn-UDP-Server/main/zi.sh; sudo chmod +x zi.sh; sudo ./zi.sh
```

#### Installation ARM
```
bash <(curl -fsSL https://raw.githubusercontent.com/Mr-Redbunny/Zivpn-UDP-Server/main/zi2.sh)
```


### Uninstall

```
sudo wget -O ziun.sh https://raw.githubusercontent.com/Mr-Redbunny/Zivpn-UDP-Server/main/uninstall.sh; sudo chmod +x ziun.sh; sudo ./ziun.sh
```

Client App available:

<a href="https://play.google.com/store/apps/details?id=com.zi.zivpn" target="_blank" rel="noreferrer">Download APP on Playstore</a>
> ZIVPN

----

### Redbunny UDP Server Manager

Server ini telah dilengkapi dengan Sistem Manajemen Pengguna Redbunny, sebuah panel CLI yang kuat namun mudah digunakan untuk mengelola banyak pengguna.

**Fitur Unggulan:**
*   **Dukungan Multi-Akun:** Buat dan kelola akun pengguna tanpa batas.
*   **Kedaluwarsa Akun:** Akun akan kedaluwarsa secara otomatis setelah durasi yang ditentukan.
*   **Menu Interaktif:** Menu yang ramah pengguna untuk mengelola semuanya. Tidak perlu menghafal perintah yang rumit!
*   **Catatan:** Fitur Batas IP tidak dapat diimplementasikan saat ini karena keterbatasan pada biner server `zivpn`.

**Cara Menggunakan Menu Manajemen**

1.  Login ke server Anda melalui SSH.
2.  Jalankan perintah berikut:
    ```bash
    rb-menu
    ```
3.  Menu interaktif akan muncul, memungkinkan Anda untuk:
    *   Menambah pengguna baru.
    *   Menghapus pengguna yang ada.
    *   Melihat semua akun pengguna beserta kata sandi dan tanggal kedaluwarsa.
    *   Memperbarui server VPN inti.
    *   Menghapus instalan server VPN sepenuhnya.

----
Bash script by PowerMX
