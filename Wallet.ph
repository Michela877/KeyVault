import os
import curses

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
    stdscr.addstr(0, 0, "Seleziona applicativo esistente o aggiungi nuovo:")

    data = leggi_database()
    applicativi = sorted(set(app for app, _, _ in data))  # Lista degli applicativi esistenti
    applicativi.append("Nuovo applicativo")  # Aggiungi la scelta di nuovo applicativo
    applicativi.append("Indietro")  # Aggiungi la possibilità di tornare indietro
    selezione_app = mostra_menu(stdscr, "Seleziona applicativo:", applicativi)

    if selezione_app == len(applicativi) - 1:  # Se scegli "Indietro"
        return  # Torna indietro senza fare nulla
    elif selezione_app == len(applicativi) - 2:  # Se scegli "Nuovo applicativo"
        stdscr.clear()  # Pulisce la schermata
        stdscr.addstr(2, 0, "Nome applicativo: ")
        stdscr.refresh()
        curses.echo()  # Abilita la visualizzazione dei caratteri digitati
        applicativo = stdscr.getstr(3, 0, 20).decode("utf-8")
        curses.noecho()  # Disabilita la visualizzazione dei caratteri digitati dopo l'input
    else:
        applicativo = applicativi[selezione_app]


    stdscr.addstr(4, 0, "ID: ")
    stdscr.refresh()
    curses.echo()  # Abilita la visualizzazione dei caratteri digitati
    app_id = stdscr.getstr(5, 0, 20).decode("utf-8")
    curses.noecho()  # Disabilita la visualizzazione dei caratteri digitati dopo l'input

    stdscr.addstr(6, 0, "Password: ")
    stdscr.refresh()
    curses.echo()  # Abilita la visualizzazione dei caratteri digitati
    pwd = stdscr.getstr(7, 0, 20).decode("utf-8")
    curses.noecho()  # Disabilita la visualizzazione dei caratteri digitati dopo l'input

    # Aggiungi il nuovo ID e password al database
    data.append((applicativo, app_id, pwd))
    scrivi_database(data)

    stdscr.addstr(9, 0, "Password aggiunta con successo!")
    stdscr.refresh()
    stdscr.getch()




def reset_wallet(stdscr):
    opzioni = ["Indietro", "Reset completo", "Cancella un applicativo"]
    selezione = mostra_menu(stdscr, "Seleziona tipo di reset:", opzioni)
    if selezione == 0:
        return
    elif selezione == 1:
        scrivi_database([])
        stdscr.clear()
        stdscr.addstr(0, 0, "Reset completo eseguito!")
    elif selezione == 2:
        data = leggi_database()
        applicativi = ["Indietro"] + sorted(set(app for app, _, _ in data))
        selezione_app = mostra_menu(stdscr, "Seleziona applicativo da cancellare:", applicativi)
        if selezione_app == 0:
            return

        app_da_eliminare = applicativi[selezione_app]

        # Aggiungi una scelta per l'utente: elimina tutto o elimina ID specifici
        opzioni_eliminazione = ["Indietro", "Elimina intero applicativo", "Elimina ID specifici"]
        selezione_eliminazione = mostra_menu(stdscr, f"Seleziona cosa fare con {app_da_eliminare}:", opzioni_eliminazione)

        if selezione_eliminazione == 0:
            return

        if selezione_eliminazione == 1:  # Elimina intero applicativo
            # Rimuove tutte le voci per l'applicativo selezionato
            data = [record for record in data if record[0] != app_da_eliminare]
            scrivi_database(data)
            stdscr.clear()
            stdscr.addstr(0, 0, f"Applicativo {app_da_eliminare} eliminato!")
        
        elif selezione_eliminazione == 2:  # Elimina ID specifici
            # Seleziona gli ID da eliminare
            ids = sorted(set(app_id for app, app_id, _ in data if app == app_da_eliminare))
            ids.append("Indietro")  # Aggiungi la possibilità di tornare indietro
            selezione_id = mostra_menu(stdscr, f"Seleziona ID per {app_da_eliminare} da eliminare:", ids)

            if selezione_id == len(ids) - 1:  # Se l'utente seleziona "Indietro"
                return

            id_da_eliminare = ids[selezione_id]
            # Rimuove solo l'ID selezionato per l'applicativo
            data = [record for record in data if not (record[0] == app_da_eliminare and record[1] == id_da_eliminare)]
            scrivi_database(data)
            stdscr.clear()
            stdscr.addstr(0, 0, f"ID {id_da_eliminare} per {app_da_eliminare} eliminato!")
        
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
