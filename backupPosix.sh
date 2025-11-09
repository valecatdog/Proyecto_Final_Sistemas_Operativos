#!/bin/sh
# Script de backup POSIX-compatible

# Configuración de rutas y conexión
BACKUP_DIR="/var/users_backups"       # Directorio local donde se almacenan los backups
LOG_FILE="/var/log/backup.log"        # Archivo de registro de actividades del sistema
REMOTE_USER="respaldo_user"           # Usuario para conexión SSH al servidor remoto
REMOTE_HOST="192.168.0.93"            # Dirección IP del servidor de backups remoto
REMOTE_PATH="/backups/usuarios"       # Ruta destino en el servidor remoto
SSH_KEY="/root/.ssh/backup_key"       # Ruta de la clave SSH para autenticación

# Programa una transferencia remota usando 'at' para ejecución retardada
# El comando 'at' permite ejecutar comandos en un momento específico sin bloquear el script
programar_rsync() {
    ARCHIVO_LOCAL="$1"                # Ruta completa del archivo de backup local
    TIEMPO_AT="now + 3 minutes"       # Tiempo de ejecución: 3 minutos desde ahora
    
    echo "Programando transferencia remota para $ARCHIVO_LOCAL a $TIEMPO_AT..." >> "$LOG_FILE"

    # en POSIX usamos comillas simples y anidadas para evitar escapes complejos
    # El comando completo se pasa a 'at' como una cadena única
    # -i especifica la clave SSH, StrictHostKeyChecking=no evita prompts de verificación
    echo '/usr/bin/rsync -avz -e "ssh -i '"$SSH_KEY"' -o StrictHostKeyChecking=no" "'"$ARCHIVO_LOCAL"'" "'"$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"'" >> "'"$LOG_FILE"'" 2>&1' | at "$TIEMPO_AT"
    
    echo "Transferencia remota programada con 'at'." >> "$LOG_FILE"
}

# Crea un backup local de un usuario y programa su transferencia remota
# En POSIX, las funciones son más simples pero igual de funcionales
backup_local() {
    TARGET="$1"                       # Nombre del usuario a respaldar
    
    # En POSIX no existe &>/dev/null, se usa >/dev/null 2>&1 para silenciar output
    # Verificamos si el objetivo es un usuario existente en el sistema
    # DIFERENCIA: En POSIX usamos grep en /etc/passwd en lugar de 'id' para mayor portabilidad
    if grep -q "^$TARGET:" /etc/passwd 2>/dev/null; then
        TARGET_PATH="/home/$TARGET"   # Ruta del directorio home del usuario
        FILE_NAME="${TARGET}_$(date +%Y%m%d_%H%M%S).tar.bz2" # .tar.bz2 para bzip2
        echo "Iniciando respaldo de usuario: $TARGET" >> "$LOG_FILE"
    
    # getent no es POSIX estandar, usamos grep en /etc/group como alternativa
    # Esta parte detecta si el objetivo es un grupo (aunque no implementa el respaldo de grupos)
    elif grep -q "^$TARGET:" /etc/group 2>/dev/null; then
        echo "Advertencia: El respaldo de grupos no está implementado en este script, solo usuarios." >> "$LOG_FILE"
        return 1                      # Retornamos error para indicar fallo
    
    # Si no es usuario ni grupo, es un objetivo inválido
    else
        echo "Error: Objetivo '$TARGET' no es un usuario conocido." >> "$LOG_FILE"
        return 1                      # Retornamos error
    fi
    
    # Creamos el directorio de backups si no existe
    #  En POSIX no confiamos en 'mkdir -p', hacemos verificación manual
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir "$BACKUP_DIR" 2>/dev/null || {
            echo "Error: No se pudo crear directorio $BACKUP_DIR" >> "$LOG_FILE"
            return 1
        }
    fi

    ARCHIVE_PATH="$BACKUP_DIR/$FILE_NAME"  # Ruta completa del archivo de backup
    
    # CORREGIDO: Comentario actualizado para bzip2
    # -c crear archivo, -j comprimir con bzip2, -f especificar archivo output
    # -C / cambia el directorio raíz para paths relativos en el tar
    # >> "$LOG_FILE" 2>&1 redirige stdout y stderr al logfile
    if tar -cjf "$ARCHIVE_PATH" -C / "$TARGET_PATH" >> "$LOG_FILE" 2>&1; then
        echo "Backup local creado exitosamente: $ARCHIVE_PATH" >> "$LOG_FILE"
        programar_rsync "$ARCHIVE_PATH"  # Programamos transferencia remota
    else
        echo "Error al crear el backup local de $TARGET." >> "$LOG_FILE"
        return 1
    fi
}

# Verificación de parámetros de entrada
# En POSIX, [ "$#" -ne 1 ] es la forma estándar (no se usa [[ ]])
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <usuario>" >> "$LOG_FILE"
    echo "Error: Se requiere un usuario como parámetro."
    exit 1
fi

# Ejecución principal del script
backup_local "$1"

# Salida con código de estado (0=éxito, 1=error)
# En shell scripting, 0 siempre significa éxito, cualquier otro número significa error :)
exit 0