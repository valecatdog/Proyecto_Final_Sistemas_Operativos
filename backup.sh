#!/bin/bash

dir_backup="/var/users_backups"
Delta=$(realpath "$0")
lockfile="/var/lock/backup-script.lock"
backup_list="/etc/backup-script/auto-backup-list.conf"
REMOTE_BACKUP_USER="respaldo_user"
REMOTE_BACKUP_HOST="192.168.0.93"
REMOTE_BACKUP_DIR="/backups/usuarios"
SSH_KEY="/root/.ssh/backup_key"
REMOTE_BACKUP_ENABLED=true

CRON_HORA="3"
CRON_MINUTO="10"
RSYNC_DELAY_MINUTOS="5"

cleanup() {
    echo "$(date): [CLEANUP] Ejecutando limpieza..." >> /var/log/backups.log
    if [ -f "$lockfile" ]; then
        local current_pid=$$
        local lock_pid=$(cat "$lockfile" 2>/dev/null)
        
        if [ "$lock_pid" = "$current_pid" ] || [ -z "$lock_pid" ] || ! ps -p "$lock_pid" > /dev/null 2>&1; then
            rm -f "$lockfile"
            echo "$(date): [CLEANUP] Lockfile removido (PID: $lock_pid, Current: $current_pid)" >> /var/log/backups.log
        else
            echo "$(date): [CLEANUP] Lockfile NO removido - pertenece a proceso activo PID: $lock_pid" >> /var/log/backups.log
        fi
    fi
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        echo "$(date): [CLEANUP] Directorio temporal removido: $temp_dir" >> /var/log/backups.log
    fi
}

trap cleanup EXIT INT TERM

check_user() {
    if [ "$(whoami)" != "root" ]; then
        echo "ERROR: Este script debe ejecutarse con sudo o como root"
        echo "Uso: sudo $0"
        exit 1
    fi
}

formato_am_pm() {
    local hora_24h="$1"
    if [ "$hora_24h" -eq 0 ]; then
        echo "12 AM"
    elif [ "$hora_24h" -eq 12 ]; then
        echo "12 PM"
    elif [ "$hora_24h" -lt 12 ]; then
        echo "${hora_24h} AM"
    else
        local hora_pm=$((hora_24h - 12))
        echo "${hora_pm} PM"
    fi
}

get_cron_hora_completa() {
    local hora_ampm=$(formato_am_pm "$CRON_HORA")
    local minuto_formateado=$(printf "%02d" "$CRON_MINUTO")
    echo "${CRON_HORA}:${minuto_formateado} ($hora_ampm)"
}

get_cron_hora_ampm() {
    formato_am_pm "$CRON_HORA"
}

acquire_lock() {
    if [ -f "$lockfile" ]; then
        local lock_pid=$(cat "$lockfile" 2>/dev/null)
        if [ -n "$lock_pid" ] && ps -p "$lock_pid" > /dev/null 2>&1; then
            echo "ERROR: El script ya se está ejecutando en otro proceso (PID: $lock_pid)"
            echo "Lockfile encontrado: $lockfile"
            return 1
        else
            rm -f "$lockfile"
        fi
    fi
    
    echo $$ > "$lockfile"
    return 0
}

release_lock() {
    if [ -f "$lockfile" ]; then
        rm -f "$lockfile"
    fi
}

execute_with_lock() {
    if ! acquire_lock; then
        return 1
    fi
    
    "$@"
    local result=$?
    
    release_lock
    
    return $result
}

realizar_respaldo_remoto() {
    local archivo_backup="$1"
    local nombre_archivo=$(basename "$archivo_backup")
    
    if [ "$REMOTE_BACKUP_ENABLED" != "true" ]; then
        return 0
    fi
    
    echo "Iniciando respaldo remoto de $nombre_archivo..."
    
    if [ ! -f "$archivo_backup" ]; then
        echo "ERROR: El archivo local $archivo_backup no existe"
        return 1
    fi
    
    if [ ! -f "$SSH_KEY" ]; then
        echo "ERROR: Clave SSH no encontrada en $SSH_KEY"
        return 1
    fi
    
    if rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
        "$archivo_backup" \
        "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST:$REMOTE_BACKUP_DIR/" 2>/dev/null; then
        
        echo "Respaldo remoto completado: $nombre_archivo"
        echo "$(date): Respaldo remoto exitoso: $nombre_archivo" >> /var/log/backups.log
        return 0
    else
        echo "ERROR: Falló el respaldo remoto de $nombre_archivo"
        echo "$(date): ERROR en respaldo remoto: $nombre_archivo" >> /var/log/backups.log
        return 1
    fi
}

programar_transferencia_remota() {
    local archivo_backup="$1"
    local delay_minutos="${2:-$RSYNC_DELAY_MINUTOS}"
    
    if [ "$REMOTE_BACKUP_ENABLED" != "true" ]; then
        return 0
    fi
    
    if [ ! -f "$archivo_backup" ]; then
        echo "ERROR: Archivo no encontrado para transferencia: $archivo_backup"
        return 1
    fi
    
    local nombre_archivo=$(basename "$archivo_backup")
    local temp_script=$(mktemp /tmp/rsync_job_XXXXXX.sh)
    
    cat > "$temp_script" << 'SCRIPT_EOF'
#!/bin/bash

LOG_FILE="/var/log/backups.log"
SCRIPT_SELF="$0"

cleanup_transfer() {
    rm -f "$SCRIPT_SELF"
}
trap cleanup_transfer EXIT

echo "$(date): [AT-TRANSFER] Iniciando transferencia programada" >> "$LOG_FILE"

if /usr/bin/rsync -avz -e "ssh -i SSH_KEY_PLACEHOLDER -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
    "BACKUP_FILE_PLACEHOLDER" \
    "REMOTE_USER_PLACEHOLDER@REMOTE_HOST_PLACEHOLDER:REMOTE_DIR_PLACEHOLDER/" >> "$LOG_FILE" 2>&1; then
    echo "$(date): [AT-TRANSFER] Transferencia exitosa" >> "$LOG_FILE"
else
    echo "$(date): [AT-TRANSFER] ERROR en transferencia" >> "$LOG_FILE"
fi
SCRIPT_EOF
    
    sed -i "s|SSH_KEY_PLACEHOLDER|$SSH_KEY|g" "$temp_script"
    sed -i "s|BACKUP_FILE_PLACEHOLDER|$archivo_backup|g" "$temp_script"
    sed -i "s|REMOTE_USER_PLACEHOLDER|$REMOTE_BACKUP_USER|g" "$temp_script"
    sed -i "s|REMOTE_HOST_PLACEHOLDER|$REMOTE_BACKUP_HOST|g" "$temp_script"
    sed -i "s|REMOTE_DIR_PLACEHOLDER|$REMOTE_BACKUP_DIR|g" "$temp_script"
    
    chmod +x "$temp_script"
    
    local tiempo_at="now + $delay_minutos minutes"
    if echo "$temp_script" | at "$tiempo_at" 2>/dev/null; then
        local job_id=$(atq | tail -n 1 | awk '{print $1}')
        echo "Transferencia remota programada con 'at'. Trabajo ID: $job_id"
        echo "$(date): Transferencia programada con at (Job $job_id) para: $nombre_archivo" >> /var/log/backups.log
        return 0
    else
        echo "ERROR: No se pudo programar la transferencia remota con at"
        echo "$(date): ERROR al programar transferencia at para: $nombre_archivo" >> /var/log/backups.log
        rm -f "$temp_script"
        return 1
    fi
}

probar_conexion_remota() {
    echo "Probando conexión con servidor remoto..."
    
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo 'Conexión exitosa'" 2>/dev/null; then
        echo "✅ Conexión remota funcionando correctamente"
        return 0
    else
        echo "❌ Error en conexión remota"
        return 1
    fi
}

configurar_respaldo_remoto() {
    while true; do
        clear
        echo "=== CONFIGURACIÓN DE RESPALDO REMOTO ==="
        echo "Estado actual: $REMOTE_BACKUP_ENABLED"
        echo "Delay de transferencia: $RSYNC_DELAY_MINUTOS minutos"
        echo "Hora de backup automático: $(get_cron_hora_completa)"
        echo
        echo "1. Activar/Desactivar respaldo remoto"
        echo "2. Probar conexión remota"
        echo "3. Ver configuración actual"
        echo "4. Configurar delay de transferencia (actual: $RSYNC_DELAY_MINUTOS min)"
        echo "5. Configurar hora del backup automático (actual: $(get_cron_hora_completa))"
        echo "0. Volver al menú principal"
        echo
        echo -n "Seleccione opción: "
        read opcion
        
        case $opcion in
            1)
                if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
                    REMOTE_BACKUP_ENABLED="false"
                    echo "Respaldo remoto DESACTIVADO"
                else
                    REMOTE_BACKUP_ENABLED="true"
                    echo "Respaldo remoto ACTIVADO"
                fi
                ;;
            2)
                probar_conexion_remota
                ;;
            3)
                echo "Configuración actual:"
                echo "  Usuario remoto: $REMOTE_BACKUP_USER"
                echo "  Host remoto: $REMOTE_BACKUP_HOST"
                echo "  Directorio remoto: $REMOTE_BACKUP_DIR"
                echo "  Clave SSH: $SSH_KEY"
                echo "  Habilitado: $REMOTE_BACKUP_ENABLED"
                echo "  Delay transferencia: $RSYNC_DELAY_MINUTOS minutos"
                echo "  Hora de backup: $(get_cron_hora_completa)"
                ;;
            4)
                echo -n "Nuevo delay en minutos (actual: $RSYNC_DELAY_MINUTOS): "
                read nuevo_delay
                if [[ "$nuevo_delay" =~ ^[0-9]+$ ]] && [ "$nuevo_delay" -gt 0 ]; then
                    RSYNC_DELAY_MINUTOS="$nuevo_delay"
                    echo "Delay de transferencia actualizado a $RSYNC_DELAY_MINUTOS minutos"
                else
                    echo "Error: Debe ingresar un número positivo"
                fi
                ;;
            5)
                echo "Configuración de hora del backup automático"
                echo "Hora actual: $(get_cron_hora_completa)"
                echo
                
                echo -n "Nueva hora (0-23, actual: $CRON_HORA): "
                read nueva_hora
                if [[ "$nueva_hora" =~ ^[0-9]+$ ]] && [ "$nueva_hora" -ge 0 ] && [ "$nueva_hora" -le 23 ]; then
                    CRON_HORA="$nueva_hora"
                    echo "Hora actualizada a $nueva_hora"
                else
                    echo "Error: Hora debe ser entre 0 y 23"
                    echo -n "¿Continuar configurando los minutos? (s/n): "
                    read continuar
                    if [ "$continuar" != "s" ]; then
                        continue
                    fi
                fi
                
                echo -n "Nuevo minuto (0-59, actual: $CRON_MINUTO): "
                read nuevo_minuto
                if [[ "$nuevo_minuto" =~ ^[0-9]+$ ]] && [ "$nuevo_minuto" -ge 0 ] && [ "$nuevo_minuto" -le 59 ]; then
                    CRON_MINUTO="$nuevo_minuto"
                    echo "Minuto actualizado a $nuevo_minuto"
                else
                    echo "Error: Minuto debe ser entre 0 y 59"
                fi
                
                echo "Hora de backup actualizada a: $(get_cron_hora_completa)"
                echo "$(date): Hora de backup cambiada a $(get_cron_hora_completa)" >> /var/log/backups.log
                ;;
            0)
                return 0
                ;;
            *)
                echo "Opción inválida"
                ;;
        esac
        
        echo
        echo "Presione Enter para continuar..."
        read
    done
}

crear_dir_backup(){
    if [ ! -d "$dir_backup" ]; then
        mkdir -p "$dir_backup"
        chmod 700 "$dir_backup"
        echo "Directorio de backups creado: $dir_backup"
    fi

    if [ ! -f "/var/log/backups.log" ]; then
        touch "/var/log/backups.log"
        chmod 644 "/var/log/backups.log"
    fi
    
    if [ ! -d "/etc/backup-script" ]; then
        mkdir -p "/etc/backup-script"
        chmod 700 "/etc/backup-script"
    fi
    
    if [ ! -f "$backup_list" ]; then
        touch "$backup_list"
        chmod 600 "$backup_list"
        echo "# Lista de usuarios y grupos para backup automatico" > "$backup_list"
        echo "# Formato: usuario o @grupo" >> "$backup_list"
        echo "# Ejemplo:" >> "$backup_list"
        echo "# usuario1" >> "$backup_list"
        echo "# @developers" >> "$backup_list"
    fi
}

backup_automatico_activo(){
    crontab -l 2>/dev/null | grep -q "$Delta"
}

menu_alpha(){
    clear
    echo "=== GESTOR DE BACKUPS ==="
    echo "1. Crear backup manual"
    
    if backup_automatico_activo; then
        echo "2. DESACTIVAR backup diario automático  [ACTIVO]"
    else
        echo "2. ACTIVAR backup diario automático   [INACTIVO]"
    fi
    echo "3. Restaurar backup"
    echo "4. Gestionar lista de backups automáticos"
    echo "5. Configurar respaldo remoto"
    echo "6. Probar backup automático (ejecuta ahora)"
    echo "0. Salir"
    echo
    echo -n "Seleccione opción (0 para salir): "
}

usuario_existe() { 
    local usuario="$1"
    id "$usuario" &>/dev/null
}

grupo_existe() {
    local grupo="$1"
    getent group "$grupo" &>/dev/null
}

obtener_usuarios_de_grupo() {
    local grupo="$1"
    getent group "$grupo" | cut -d: -f4 | tr ',' '\n'
}

leer_con_cancelar() {
    local prompt="$1"
    local variable="$2"
    echo -n "$prompt (o '0' para cancelar): "
    read $variable
    if [ "${!variable}" = "0" ]; then
        echo "Operación cancelada."
        return 1
    fi
    return 0
}

menu_gestion_backup_auto() {
    clear
    echo "=== GESTIÓN DE BACKUPS AUTOMÁTICOS ==="
    echo "1. Ver lista actual"
    echo "2. Añadir usuario a la lista"
    echo "3. Añadir grupo a la lista"
    echo "4. Eliminar elemento de la lista"
    echo "0. Volver al menú principal"
    echo
    echo -n "Seleccione opción: "
}

ver_lista_backup_auto() {
    echo "=== LISTA ACTUAL DE BACKUPS AUTOMÁTICOS ==="
    if [ ! -s "$backup_list" ]; then
        echo "La lista está vacía."
        echo "Los backups automáticos no se ejecutarán hasta que añada elementos."
    else
        grep -v '^#' "$backup_list" | grep -v '^$' | nl -w 2 -s '. '
    fi
    echo
}

añadir_usuario_backup_auto() {
    if ! leer_con_cancelar "Ingrese nombre de usuario a añadir" usuario; then
        return 1
    fi
    
    if usuario_existe "$usuario"; then
        if grep -q "^$usuario$" "$backup_list"; then
            echo "El usuario $usuario ya está en la lista."
        else
            echo "$usuario" >> "$backup_list"
            echo "Usuario $usuario añadido a la lista de backups automáticos."
        fi
    else
        echo "El usuario $usuario no existe."
    fi
}

añadir_grupo_backup_auto() {
    if ! leer_con_cancelar "Ingrese nombre del grupo a añadir" grupo; then
        return 1
    fi
    
    if grupo_existe "$grupo"; then
        grupo_line="@$grupo"
        if grep -q "^$grupo_line$" "$backup_list"; then
            echo "El grupo $grupo ya está en la lista."
        else
            echo "$grupo_line" >> "$backup_list"
            echo "Grupo $grupo añadido a la lista de backups automáticos."
        fi
    else
        echo "El grupo $grupo no existe."
    fi
}

eliminar_elemento_backup_auto() {
    ver_lista_backup_auto
    
    if [ ! -s "$backup_list" ]; then
        return 1
    fi
    
    echo
    if ! leer_con_cancelar "Ingrese el número del elemento a eliminar" numero; then
        return 1
    fi
    
    elemento=$(grep -v '^#' "$backup_list" | grep -v '^$' | sed -n "${numero}p")
    
    if [ -z "$elemento" ]; then
        echo "Número inválido."
        return 1
    fi
    
    echo "¿Eliminar '$elemento' de la lista?"
    echo -n "Confirmar (s/n): "
    read confirmacion
    
    if [ "$confirmacion" = "s" ]; then
        temp_file=$(mktemp)
        grep -v "^$elemento$" "$backup_list" > "$temp_file"
        mv "$temp_file" "$backup_list"
        echo "Elemento '$elemento' eliminado."
    else
        echo "Operación cancelada."
    fi
}

gestionar_backup_auto() {
    while true; do
        menu_gestion_backup_auto
        read opcion
        
        case $opcion in
            1)
                ver_lista_backup_auto
                ;;
            2)
                añadir_usuario_backup_auto
                ;;
            3)
                añadir_grupo_backup_auto
                ;;
            4)
                eliminar_elemento_backup_auto
                ;;
            0)
                echo "Volviendo al menú principal..."
                return 0
                ;;
            *)
                echo "Opción inválida"
                ;;
        esac
        
        echo
        echo "Presione Enter para continuar..."
        read
    done
}

crear_backup_grupo(){
    if ! leer_con_cancelar "Ingrese nombre del grupo" grupo; then
        return 1
    fi
    
    if grupo_existe "$grupo"; then
        fecha=$(date '+%Y%m%d_%H%M%S')
        
        echo "Creando backup del grupo: $grupo"
        echo "Usuarios en el grupo:"
        
        local temp_counter=$(mktemp)
        echo "0" > "$temp_counter"
        
        while IFS= read -r usuario; do
            if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    echo "  - Creando backup de: $usuario"
                    archivo_backup="${dir_backup}/backup_${usuario}_grupo_${fecha}.tar.bz2"
                    
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                        echo "    Backup creado: $(basename "$archivo_backup")"
                        echo "$(date): Backup manual de grupo $grupo - usuario $usuario - $archivo_backup" >> /var/log/backups.log
                        local current_count=$(cat "$temp_counter")
                        echo $((current_count + 1)) > "$temp_counter"
                        programar_transferencia_remota "$archivo_backup"
                    else
                        echo "    Error al crear backup de $usuario"
                    fi
                fi
            else
                echo "  - Usuario $usuario no existe, omitiendo"
            fi
        done < <(obtener_usuarios_de_grupo "$grupo")
        
        local usuarios_procesados=$(cat "$temp_counter")
        rm -f "$temp_counter"
        
        echo "Backup de grupo completado: $usuarios_procesados usuarios procesados"
        
    else
        echo "El grupo $grupo no existe."
        return 1
    fi
}

crear_backup(){
    while true; do
        echo "¿Qué tipo de backup desea crear?"
        echo "1. Backup de usuario individual"
        echo "2. Backup de grupo (backups individuales por usuario)"
        echo "0. Volver al menú principal"
        read -p "Seleccione opción: " tipo_backup

        case $tipo_backup in
            1)
                if ! leer_con_cancelar "Ingrese nombre de usuario" usuario; then
                    break
                fi

                if usuario_existe "$usuario"; then
                    home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                    fecha=$(date '+%Y%m%d_%H%M%S')
                    archivo_backup="/var/users_backups/backup_${usuario}_${fecha}.tar.bz2"
                    
                    echo "Creando backup de $home_dir"
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                        echo "Backup creado: $archivo_backup"
                        echo "$(date): Backup manual de $usuario - $archivo_backup" >> /var/log/backups.log
                        programar_transferencia_remota "$archivo_backup"
                    else
                        echo "Error al crear el backup"
                    fi
                else 
                    echo "El usuario $usuario no existe."
                fi
                break
                ;;
            2)
                crear_backup_grupo
                break
                ;;
            0)
                echo "Volviendo al menú principal..."
                return 1
                ;;
            *)
                echo "Opción inválida"
                ;;
        esac
    done
}

backup_diario(){
    if ! acquire_lock; then
        echo "$(date): No se pudo adquirir lock, backup automático omitido" >> /var/log/backups.log
        return 1
    fi
    
    local fecha=$(date '+%Y%m%d')
    local usuarios_procesados=0
    local archivos_creados=()

    echo "$(date): Iniciando backup automático" >> /var/log/backups.log

    if [ ! -f "$backup_list" ] || [ ! -s "$backup_list" ]; then
        echo "$(date): Lista de backups automáticos vacía, no se realizaron backups" >> /var/log/backups.log
        release_lock
        return 0
    fi

    while IFS= read -r linea; do
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue
        
        if [[ "$linea" =~ ^@ ]]; then
            grupo="${linea#@}"
            if grupo_existe "$grupo"; then
                echo "$(date): Procesando grupo $grupo" >> /var/log/backups.log
                while IFS= read -r usuario; do
                    if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                        home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                        if [ -d "$home_dir" ]; then
                            archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                            if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                                echo "$(date): Backup automático de $usuario (grupo $grupo) - $archivo_backup" >> /var/log/backups.log
                                ((usuarios_procesados++))
                                archivos_creados+=("$archivo_backup")
                            fi
                        fi
                    fi
                done < <(obtener_usuarios_de_grupo "$grupo")
            else
                echo "$(date): ERROR: Grupo $grupo no existe" >> /var/log/backups.log
            fi
        else
            usuario="$linea"
            if usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                        echo "$(date): Backup automático de $usuario - $archivo_backup" >> /var/log/backups.log
                        ((usuarios_procesados++))
                        archivos_creados+=("$archivo_backup")
                    fi
                fi
            else
                echo "$(date): ERROR: Usuario $usuario no existe" >> /var/log/backups.log
            fi
        fi
    done < "$backup_list"

    if [ ${#archivos_creados[@]} -gt 0 ] && [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
        echo "$(date): Programando transferencias remotas para ${#archivos_creados[@]} archivos" >> /var/log/backups.log
        for archivo in "${archivos_creados[@]}"; do
            programar_transferencia_remota "$archivo" "$RSYNC_DELAY_MINUTOS"
        done
    fi

    echo "$(date): Backup automático completado - $usuarios_procesados usuarios procesados" >> /var/log/backups.log
    release_lock
    return 0
}

toggle_backup_automatico(){
    if backup_automatico_activo; then
        (crontab -l 2>/dev/null | grep -v "$Delta") | crontab -
        echo "Backup automático DESACTIVADO"
        echo "$(date): Backup automático desactivado" >> /var/log/backups.log
    else
        if [ ! -f "$backup_list" ] || ! grep -v '^#' "$backup_list" | grep -v '^$' | read; then
            echo "¡ADVERTENCIA: La lista de backups automáticos está vacía!"
            echo "No se realizarán backups hasta que añada usuarios/grupos."
            echo "Puede gestionar la lista en la opción 4 del menú principal."
            echo
        fi
        
        if [ -n "$CRON_MINUTO" ] && [ -n "$CRON_HORA" ] && [ -x "$Delta" ]; then
            (crontab -l 2>/dev/null; echo "$CRON_MINUTO $CRON_HORA * * * $Delta automatico") | crontab -
            echo "Backup automático ACTIVADO"
            echo "Se ejecutará diariamente a las $(get_cron_hora_completa)"
            echo "Las transferencias remotas se programarán con at para ejecutarse $RSYNC_DELAY_MINUTOS minutos después."
            echo "$(date): Backup automático activado - programado diariamente a las $(get_cron_hora_completa)" >> /var/log/backups.log
        else
            echo "ERROR: No se puede programar backup automático - verifique configuración"
        fi
    fi
}

restaurar_backup(){
    while true; do
        echo "Backups disponibles:"
        ls -1 "$dir_backup"/*.tar.bz2 2>/dev/null | nl -w 2 -s '. '

        if [ $? -ne 0 ]; then
            echo "No hay backups disponibles."
            echo "Presione Enter para continuar..."
            read
            return 1
        fi

        echo
        echo -n "Seleccione el numero del backup a restaurar (0 para volver): "
        read numero 

        if [ "$numero" = "0" ]; then
            echo "Volviendo al menú principal..."
            return 1
        fi

        archivo_backup=$(ls -1 "$dir_backup"/*.tar.bz2 | sed -n "${numero}p")

        if [ -z "$archivo_backup" ]; then
            echo "Numero invalido"
            continue
        fi
        
        nombre_archivo=$(basename "$archivo_backup")
        
        if [[ "$nombre_archivo" =~ ^(backup_|diario_)([^_]+)_ ]]; then
            usuario="${BASH_REMATCH[2]}"
        else
            echo "Formato de archivo de backup no reconocido: $nombre_archivo"
            continue
        fi

        echo "usuario del backup: $usuario"

        if ! usuario_existe "$usuario"; then
            echo "ERROR: El usuario $usuario no existe en el sistema"
            echo "Presione Enter para continuar..."
            read
            continue
        fi

        home_destino=$(getent passwd "$usuario" | cut -d':' -f6)

        echo 
        echo "¿Restaurar backup de $usuario en $home_destino?"
        echo "¡ADVERTENCIA: se van a sobreescribir los archivos existentes!"
        echo -n "desea continuar (s/n/0 para volver): "
        read confirmacion 
        
        if [ "$confirmacion" = "0" ]; then
            continue
        elif [ "$confirmacion" != "s" ]; then
            echo "Restauracion cancelada"
            continue
        fi

        temp_dir=$(mktemp -d)

        echo "Restaurando backup..."

        if tar -xjf "$archivo_backup" -C "$temp_dir" 2>/dev/null; then
            if [ -d "$temp_dir/home/$usuario" ]; then
                dir_origen="$temp_dir/home/$usuario" 
            elif [ -d "$temp_dir/$usuario" ]; then
                dir_origen="$temp_dir/$usuario"
            else
                dir_origen="$temp_dir"
            fi

            echo "copiando archivos a $home_destino..."
            rsync -av "$dir_origen/" "$home_destino/" 2>/dev/null

            chown -R "$usuario:$usuario" "$home_destino"

            echo "Restauración completada"
            rm -rf "$temp_dir"

        else
            echo "ERROR: No se pudo extraer el backup"
            rm -rf "$temp_dir"
        fi
        
        echo "Presione Enter para continuar..."
        read
        break
    done
}

check_user
crear_dir_backup

if [ "$1" = "automatico" ]; then
    {
        echo "================================================"
        echo "$(date): [CRON] INICIANDO BACKUP AUTOMÁTICO DIARIO"
        echo "================================================"
        
        echo "Verificando archivos necesarios..."
        if [ ! -f "$backup_list" ]; then
            echo "ERROR: No existe el archivo de lista: $backup_list"
            exit 1
        fi
        
        if [ ! -s "$backup_list" ]; then
            echo "INFO: Lista de backups vacía, no hay nada que hacer"
            exit 0
        fi
        
        echo "Ejecutando backup_diario..."
        if backup_diario; then
            echo "Backup automático diario completado exitosamente"
        else
            echo "Backup automático diario falló con código: $?"
        fi
        
        echo "================================================"
        echo "$(date): [CRON] FINALIZANDO BACKUP AUTOMÁTICO DIARIO"
        echo "================================================"
    } >> /var/log/backups.log 2>&1
    exit 0
fi

while true; do
    menu_alpha
    read opcion

    case $opcion in
        1)
            execute_with_lock crear_backup
            ;;
        2)
            toggle_backup_automatico
            ;;
        3)
            execute_with_lock restaurar_backup
            ;;
        4)
            gestionar_backup_auto
            ;;
        5)
            configurar_respaldo_remoto
            ;;
        6)
            echo "Ejecutando backup automático de prueba..."
            execute_with_lock backup_diario
            ;;
        0)
             echo "cerrando programa"
             exit 0 
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
    
    echo
    echo "Presione Enter para continuar..."
    read
done