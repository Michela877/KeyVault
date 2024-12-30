#!/bin/bash

# Percorso al file di memorizzazione delle password
DB_FILE="$HOME/.password_wallet.db"

# Controlla se il file del database esiste, altrimenti crealo
if [ ! -f "$DB_FILE" ]; then
    touch "$DB_FILE"
    chmod 600 "$DB_FILE" # Protezione del file
fi

# Funzione per visualizzare le password
function visualizza_password() {
    echo "Applicativi disponibili:"
    applicativi=("Indietro" $(cut -d':' -f1 "$DB_FILE" | sort | uniq))
    if [ ${#applicativi[@]} -eq 1 ]; then
        echo "Nessun applicativo disponibile."
        return
    fi

    select app_name in "${applicativi[@]}"; do
        if [ "$app_name" == "Indietro" ]; then
            return
        elif [ -n "$app_name" ]; then
            grep "^$app_name:" "$DB_FILE" | while IFS=: read -r app id pass; do
                echo "------------------------"
                echo "Applicativo: $app"
                echo "ID: $id"
                echo "Password: $pass"
                echo "------------------------"
            done
            break
        else
            echo "Selezione non valida."
        fi
    done
}

# Funzione per aggiungere una nuova password
function aggiungi_password() {
    echo "Seleziona un'opzione:"
    options=("Indietro" "Aggiungi nuova password")
    select scelta in "${options[@]}"; do
        case $REPLY in
            1) return ;; # Indietro
            2)
                echo "Inserisci il nome dell'applicativo:"
                read app_name
                echo "Inserisci l'ID:"
                read app_id
                echo "Inserisci la password:"
                read -s app_pass  # Input nascosto per sicurezza

                echo "$app_name:$app_id:$app_pass" >> "$DB_FILE"
                echo "Password aggiunta con successo!"
                break
                ;;
            *)
                echo "Opzione non valida."
                ;;
        esac
    done
}

# Funzione per modificare password o ID
function modifica_password() {
    echo "Applicativi disponibili:"
    applicativi=("Indietro" $(cut -d':' -f1 "$DB_FILE" | sort | uniq))

    select app_name in "${applicativi[@]}"; do
        if [ "$app_name" == "Indietro" ]; then
            return
        elif [ -n "$app_name" ]; then
            ids=("Indietro" $(grep "^$app_name:" "$DB_FILE" | cut -d':' -f2))

            select current_id in "${ids[@]}"; do
                if [ "$current_id" == "Indietro" ]; then
                    return
                elif [ -n "$current_id" ]; then
                    record=$(grep "^$app_name:$current_id:" "$DB_FILE")
                    old_pass=$(echo "$record" | cut -d':' -f3)

                    echo "Vuoi modificare:"
                    options=("Indietro" "Solo la password" "Sia ID che password")
                    select scelta_modifica in "${options[@]}"; do
                        case $REPLY in
                            1) return ;; # Indietro
                            2)
                                new_id="$current_id" # Mantieni l'ID corrente
                                echo "Inserisci la nuova password:"
                                read -s new_pass
                                ;;
                            3)
                                echo "Inserisci il nuovo ID:"
                                read new_id
                                echo "Inserisci la nuova password:"
                                read -s new_pass
                                ;;
                            *)
                                echo "Opzione non valida."
                                continue
                                ;;
                        esac
                        sed -i "s|^$app_name:$current_id:$old_pass\$|$app_name:$new_id:$new_pass|" "$DB_FILE"
                        echo "Dati aggiornati con successo!"
                        break
                    done
                    break
                else
                    echo "Selezione non valida."
                fi
            done
            break
        else
            echo "Selezione non valida."
        fi
    done
}

# Funzione per resettare le password
function reset_wallet() {
    echo "Seleziona un'opzione per il reset:"
    options=("Indietro" "Reset a impostazioni di fabbrica (cancella tutto)" "Cancella solo un applicativo specifico" "Aggiorna il file vault.sh")
    select opzione_reset in "${options[@]}"; do
        case $REPLY in
            1) return ;;
            2)
                > "$DB_FILE" # Svuota il file
                echo "Tutto resettato!"
                break
                ;;
            3)
                echo "Applicativi disponibili:"
                applicativi=("Indietro" $(cut -d':' -f1 "$DB_FILE" | sort | uniq))

                select app_to_delete in "${applicativi[@]}"; do
                    if [ "$app_to_delete" == "Indietro" ]; then
                        return
                    elif [ -n "$app_to_delete" ]; then
                        sed -i "/^$app_to_delete:/d" "$DB_FILE"
                        echo "Applicativo $app_to_delete cancellato!"
                        break
                    else
                        echo "Selezione non valida."
                    fi
                done
                break
                ;;
            4)
                # Clona o aggiorna il repository Git e sostituisce il file vault.sh
                echo "Aggiornamento del file vault.sh dal repository GitHub..."
                git clone https://github.com/Michela877/KeyVault.git /tmp/KeyVault || (cd /tmp/KeyVault && git pull)
                if [ -f /tmp/KeyVault/vault.sh ]; then
                    cp /tmp/KeyVault/vault.sh "$HOME/vault.sh"
                    chmod +x "$HOME/vault.sh"  # Rende eseguibile il file
                    echo "File vault.sh aggiornato e reso eseguibile con successo!"

                    # Riavvia il programma
                    exec "$HOME/vault.sh"  # Riavvia lo script
                else
                    echo "Errore: il file vault.sh non è stato trovato nel repository."
                fi
                break
                ;;
            *)
                echo "Opzione non valida."
                ;;
        esac
    done
}

# Disabilita i segnali Ctrl+C (SIGINT) e Ctrl+Z (SIGTSTP)
trap '' SIGINT SIGTSTP

# Menu principale
while true; do
    clear
    echo "=== Password Wallet ==="
    options=("Visualizza password" "Aggiungi nuova password" "Modifica password" "Reset (Cancella tutto o un applicativo)")

    select scelta in "${options[@]}"; do
        if [ "$REPLY" == "supercalifragili" ]; then
            echo "Uscita dal programma..."
            exit 0
        fi

        case $REPLY in
            1) visualizza_password; break ;;
            2) aggiungi_password; break ;;
            3) modifica_password; break ;;
            4) reset_wallet; break ;;
            *) echo "Opzione non valida, riprova." ;;
        esac
    done

    echo "Premi INVIO per continuare..."
    read
done
