#!/bin/sh
# el shebangg se define como sh para posix a diferencia del bash para bash .
BACKUP_DIR="/var/users_backups"
LOG_FILE="/var/log/backup.log"
REMOTE_USER="respaldo_user"
REMOTE_HOST="<192.168.1.10>"
REMOTE_PATH="/backups/usuarios"

programar_rsync() {
    ARCHIVO_LOCAL="$1"
    TIEMPO_AT="now + 50 minutes"
    
    echo "Programando transferencia remota para $ARCHIVO_LOCAL a $TIEMPO_AT..." >> "$LOG_FILE"

    # En POSIX no hay here-documents con comillas, y se usa at con -c para comandos
    # También eliminamos la expansión de comandos $(atq...) que no es portable
    echo "/usr/bin/rsync -avz \"$ARCHIVO_LOCAL\" \"$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/\" >> \"$LOG_FILE\" 2>&1" | at "$TIEMPO_AT"
    
    echo "Transferencia remota programada con 'at'."
}

backup_local() {
    TARGET="$1"
    TARGET_PATH=""
    FILE_NAME=""
    
    # a diferendia de bash en POSIX no existe &>/dev/null, se ua >/dev/null 2>&1
    if id "$TARGET" >/dev/null 2>&1; then
        TARGET_PATH="/home/$TARGET"
        FILE_NAME="${TARGET}_$(date +%Y%m%d_%H%M%S).tar.bz2"
        echo "Iniciando respaldo de usuario: $TARGET" >> "$LOG_FILE"
    # getent no es POSIX estándar, pero es común. Alternativa sería grep
    elif getent group "$TARGET" >/dev/null 2>&1; then
        echo "Advertencia: El respaldo de grupos no está implementado en este script, solo usuarios." >> "$LOG_FILE"
        return 1
    else
        echo "Error: Objetivo '$TARGET' no es un usuario conocido." >> "$LOG_FILE"
        return 1
    fi
    
    mkdir -p "$BACKUP_DIR"

    ARCHIVE_PATH="$BACKUP_DIR/$FILE_NAME"
    
    # Se mantiene igual ya que tar es POSIX, pero se cambia la redirección
    if tar -cjf "$ARCHIVE_PATH" -C / "$TARGET_PATH" >> "$LOG_FILE" 2>&1; then
        echo "Backup local creado exitosamente: $ARCHIVE_PATH" >> "$LOG_FILE"
        programar_rsync "$ARCHIVE_PATH"
    else
        echo "Error al crear el backup local de $TARGET." >> "$LOG_FILE"
        return 1
    fi
}

#  En POSIX, [ "$#" -ne 1 ] es la forma estándar (no [[ ]]) :3
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <usuario>" >> "$LOG_FILE"
    echo "Error: Se requiere un usuario como parámetro."
    exit 1
fi

backup_local "$1"

exit 0