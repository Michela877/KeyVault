import os
import curses
import shutil
import subprocess

DB_FILE = os.path.expanduser("~/.password_wallet.db")

# Inizializza il file se non esiste
if not os.path.exists(DB_FILE):
    with open(DB_FILE, "w") as db:
        pass
    os.chmod(DB_FILE, 0o600)


def leggi_database():
    """Legge il database e restituisce una lista di tuple (applicativo, id, password)."""
    with open(DB_FILE, "r") as db:
        return [line.strip().split(":") for line in db.readlines()]


def scrivi_database(data):
    """Scrive i dati nel database."""
    with open(DB_FILE, "w") as db:
        for app, app_id, pwd in data:
            db.write(f"{app}:{app_id}:{pwd}\n")


def mostra_menu(stdscr, titolo, opzioni):
    """Mostra un menu e gestisce la selezione con le frecce."""
    selezione = 0
    curses.curs_set(0)
    while True:
        stdscr.clear()
        stdscr.addstr(0, 0, titolo, curses.A_BOLD)
        for i, opzione in enumerate(opzioni):
            if i == selezione:
                stdscr.addstr(i + 1, 2, f"> {opzione}", curses.A_REVERSE)
            else:
                stdscr.addstr(i + 1, 2, f"  {opzione}")
        stdscr.refresh()

        key = stdscr.getch()
        if key == curses.KEY_UP and selezione > 0:
            selezione -= 1
        elif key == curses.KEY_DOWN and selezione < len(opzioni) - 1:
            selezione += 1
        elif key in (10, 13):  # Invio
            return selezione
        elif key == ord("q"):  # Esci con 'q'
            return -1


def visualizza_password(stdscr):
    data = leggi_database()
    applicativi = ["Indietro"] + sorted(set(app for app, _, _ in data))

    selezione_app = mostra_menu(stdscr, "Seleziona applicativo:", applicativi)
    if selezione_app == 0:
        return

    app_selezionato = applicativi[selezione_app]
    ids = ["Indietro"] + [id for app, id, _ in data if app == app_selezionato]
    selezione_id = mostra_menu(stdscr, f"ID per {app_selezionato}:", ids)
    if selezione_id == 0:
        return

    id_selezionato = ids[selezione_id]
    stdscr.clear()
    for app, app_id, pwd in data:
        if app == app_selezionato and app_id == id_selezionato:
            stdscr.addstr(0, 0, f"Applicativo: {app}")
            stdscr.addstr(1, 0, f"ID: {app_id}")
            stdscr.addstr(2, 0, f"Password: {pwd}")
            break
    stdscr.refresh()
    stdscr.getch()


def aggiungi_password(stdscr):
    stdscr.clear()
    stdscr.addstr(0, 0, "Nome applicativo: ")
    stdscr.refresh()
    applicativo = stdscr.getstr(1, 0, 20).decode("utf-8")

    stdscr.addstr(2, 0, "ID: ")
    stdscr.refresh()
    app_id = stdscr.getstr(3, 0, 20).decode("utf-8")

    stdscr.addstr(4, 0, "Password: ")
    stdscr.refresh()
    pwd = stdscr.getstr(5, 0, 20).decode("utf-8")

    data = leggi_database()
    data.append((applicativo, app_id, pwd))
    scrivi_database(data)
    stdscr.addstr(7, 0, "Password aggiunta con successo!")
    stdscr.refresh()
    stdscr.getch()


def reset_wallet(stdscr):
    # Opzioni aggiornate con l'aggiunta della selezione Update
    opzioni = ["Indietro", "Reset completo", "Cancella un applicativo", "Update da repository"]
    selezione = mostra_menu(stdscr, "Seleziona tipo di reset:", opzioni)

    if selezione == 0:  # Indietro
        return
    elif selezione == 1:  # Reset completo
        scrivi_database([])
        stdscr.addstr(0, 0, "Reset completo eseguito!")
    elif selezione == 2:  # Cancella un applicativo
        data = leggi_database()
        applicativi = ["Indietro"] + sorted(set(app for app, _, _ in data))
        selezione_app = mostra_menu(stdscr, "Seleziona applicativo da cancellare:", applicativi)
        if selezione_app == 0:
            return

        app_da_eliminare = applicativi[selezione_app]
        data = [record for record in data if record[0] != app_da_eliminare]
        scrivi_database(data)
        stdscr.addstr(0, 0, f"Applicativo {app_da_eliminare} eliminato!")
    elif selezione == 3:  # Update da repository
        stdscr.addstr(0, 0, "Aggiornamento in corso...")
        stdscr.refresh()

        # Repository e percorso locale
        repo_url = "https://github.com/Michela877/KeyVault.git"
        temp_dir = "/tmp/KeyVault"
        local_file = os.path.abspath(__file__)  # Percorso del file locale

        try:
            # Clona o aggiorna il repository
            if os.path.exists(temp_dir):
                subprocess.run(["git", "-C", temp_dir, "pull"], check=True)
            else:
                subprocess.run(["git", "clone", repo_url, temp_dir], check=True)

            # Percorso del nuovo file da sostituire
            new_file = os.path.join(temp_dir, "wallet.py")

            # Controlla se il file esiste e lo sostituisce
            if os.path.exists(new_file):
                shutil.copy(new_file, local_file)
                os.chmod(local_file, 0o755)  # Rendi eseguibile il file
                stdscr.addstr(1, 0, "Aggiornamento completato! Riavvio...")
                stdscr.refresh()
                curses.napms(2000)  # Attende 2 secondi
                os.execv(local_file, ["python3"] + os.sys.argv)  # Riavvia il programma
            else:
                stdscr.addstr(1, 0, "Errore: file wallet.py non trovato nel repository!")
        except Exception as e:
            stdscr.addstr(1, 0, f"Errore durante l'aggiornamento: {e}")

    stdscr.refresh()
    stdscr.getch()


def main(stdscr):
    curses.curs_set(0)  # Nasconde il cursore
    stdscr.clear()
    while True:
        opzioni = ["Visualizza password", "Aggiungi nuova password", "Reset", "Esci"]
        selezione = mostra_menu(stdscr, "=== Password Wallet ===", opzioni)

        if selezione == 0:
            visualizza_password(stdscr)
        elif selezione == 1:
            aggiungi_password(stdscr)
        elif selezione == 2:
            reset_wallet(stdscr)
        elif selezione == 3 or selezione == -1:  # Esci
            break


if __name__ == "__main__":
    curses.wrapper(main)
