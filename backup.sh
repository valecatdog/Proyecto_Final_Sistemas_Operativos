#!/bin/bash

# Archivo de configuración persistente
CONFIG_FILE="/etc/backup-script/backup-config.conf"

# Archivo de configuracion para la lista de backups automaticos
CRON_HORA="3"
CRON_MINUTO="10"
# Nueva variable para el delay de rsync (minutos después del backup)
RSYNC_DELAY_MINUTOS="5"
REMOTE_BACKUP_ENABLED="true"
REMOTE_BACKUP_USER="respaldo_user"
REMOTE_BACKUP_HOST="192.168.0.93"
REMOTE_BACKUP_DIR="/backups/usuarios"
SSH_KEY="/root/.ssh/backup_key"


#en esta variable guardamos la direccion de donde se van a guardar los backups
dir_backup="/var/users_backups"
# tambien podriamos usar la direccion actual del script y ya, pero esto le da mas flexibilidad
# Delta es el valor actual de este scrit, lo conseguimos con realpath
Delta=$(realpath "$0")
backup_list="/etc/backup-script/auto-backup-list.conf"
#**** funcion para verificar que el script se ejecute como root
check_user() {
    if [ "$(whoami)" != "root" ]; then
        echo "ERROR: Este script debe ejecutarse con sudo o como root"
        echo "Uso: sudo $0"
        exit 1
    fi
}

# Archivo de configuración persistente
CONFIG_FILE="/etc/backup-script/backup-config.conf"

# Función para cargar configuración desde archivo
cargar_configuracion() {
    if [ -f "$CONFIG_FILE" ]; then
        # Cargar configuración desde archivo
        source "$CONFIG_FILE"
        echo "✅ Configuración cargada desde $CONFIG_FILE" >> /var/log/backups.log
    else
        # Valores por defecto si el archivo no existe
        guardar_configuracion
    fi
}

# Función para guardar configuración actual
guardar_configuracion() {
    # Crear directorio de configuración si no existe
    mkdir -p "/etc/backup-script"
    
    # Guardar todas las variables de configuración
    cat > "$CONFIG_FILE" << EOF
# Configuración de Backup Automático
# Este archivo se actualiza automáticamente - NO EDITAR MANUALMENTE

CRON_HORA="$CRON_HORA"
CRON_MINUTO="$CRON_MINUTO"
RSYNC_DELAY_MINUTOS="$RSYNC_DELAY_MINUTOS"
REMOTE_BACKUP_ENABLED="$REMOTE_BACKUP_ENABLED"
REMOTE_BACKUP_USER="$REMOTE_BACKUP_USER"
REMOTE_BACKUP_HOST="$REMOTE_BACKUP_HOST"
REMOTE_BACKUP_DIR="$REMOTE_BACKUP_DIR"
SSH_KEY="$SSH_KEY"
EOF

    chmod 600 "$CONFIG_FILE"
    echo "✅ Configuración guardada en $CONFIG_FILE" >> /var/log/backups.log
}

# Función para actualizar una variable de configuración
actualizar_configuracion() {
    local variable="$1"
    local valor="$2"
    
    # Actualizar variable en memoria
    eval "$variable=\"$valor\""
    
    # Guardar cambios en archivo
    guardar_configuracion
}

# Función para convertir hora 24h a formato AM/PM
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

# Función para obtener la hora en formato legible
get_cron_hora_completa() {
    local hora_ampm=$(formato_am_pm "$CRON_HORA")
    # Asegurar que los minutos tengan 2 dígitos
    local minuto_formateado=$(printf "%02d" "$CRON_MINUTO")
    echo "${CRON_HORA}:${minuto_formateado} ($hora_ampm)"
}

# Función para obtener solo la hora en formato legible
get_cron_hora_ampm() {
    formato_am_pm "$CRON_HORA"
}

# Función para verificar todas las dependencias del sistema
verificar_dependencias() {
    local errores=0
    
    echo "🔍 Verificando dependencias del sistema..." >> /var/log/backups.log
    
    # Verificar servicio atd
    if ! systemctl is-active --quiet atd 2>/dev/null; then
        echo "❌ SERVICIO ATD: No está activo. Ejecuta: sudo systemctl enable atd && sudo systemctl start atd" >> /var/log/backups.log
        ((errores++))
    else
        echo "✅ SERVICIO ATD: Activo" >> /var/log/backups.log
    fi
    
    # Verificar clave SSH
    if [ ! -f "$SSH_KEY" ]; then
        echo "❌ CLAVE SSH: No encontrada en $SSH_KEY" >> /var/log/backups.log
        ((errores++))
    elif [ "$(stat -c %a "$SSH_KEY" 2>/dev/null)" != "600" ]; then
        echo "⚠️  CLAVE SSH: Permisos incorrectos. Ajustando..." >> /var/log/backups.log
        chmod 600 "$SSH_KEY"
        echo "✅ CLAVE SSH: Permisos corregidos" >> /var/log/backups.log
    else
        echo "✅ CLAVE SSH: Encontrada y con permisos correctos" >> /var/log/backups.log
    fi
    
    # Verificar conectividad remota
    if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
        if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo 'OK'" &>/dev/null; then
            echo "❌ CONECTIVIDAD: No se puede conectar a $REMOTE_BACKUP_HOST" >> /var/log/backups.log
            ((errores++))
        else
            echo "✅ CONECTIVIDAD: Conexión remota funcionando" >> /var/log/backups.log
        fi
    fi
    
    # Verificar permisos de ejecución del script
    if [ ! -x "$Delta" ]; then
        echo "⚠️  PERMISOS SCRIPT: No es ejecutable. Ajustando..." >> /var/log/backups.log
        chmod +x "$Delta"
        echo "✅ PERMISOS SCRIPT: Corregidos" >> /var/log/backups.log
    else
        echo "✅ PERMISOS SCRIPT: Ejecutable" >> /var/log/backups.log
    fi
    
    # Verificar configuración de cron
    if [ -z "$CRON_HORA" ] || [ -z "$CRON_MINUTO" ]; then
        echo "❌ CONFIG CRON: Variables CRON_HORA o CRON_MINUTO no configuradas" >> /var/log/backups.log
        ((errores++))
    else
        echo "✅ CONFIG CRON: Hora programada: $(get_cron_hora_completa)" >> /var/log/backups.log
    fi
    
    if [ $errores -eq 0 ]; then
        echo "✅ TODAS LAS DEPENDENCIAS: Verificadas correctamente" >> /var/log/backups.log
    else
        echo "❌ SE ENCONTRARON $errores ERROR(ES) en las dependencias" >> /var/log/backups.log
    fi
    
    return $errores
}

# Función para realizar respaldo remoto
realizar_respaldo_remoto() {
    local archivo_backup="$1"
    local nombre_archivo=$(basename "$archivo_backup")
    
    # Verificar si está habilitado el respaldo remoto
    if [ "$REMOTE_BACKUP_ENABLED" != "true" ]; then
        return 0
    fi
    
    echo "Iniciando respaldo remoto de $nombre_archivo..."
    
    # Verificar si el archivo local existe
    if [ ! -f "$archivo_backup" ]; then
        echo "ERROR: El archivo local $archivo_backup no existe"
        return 1
    fi
    
    # Verificar que la clave SSH existe
    if [ ! -f "$SSH_KEY" ]; then
        echo "ERROR: Clave SSH no encontrada en $SSH_KEY"
        return 1
    fi
    
    # Realizar el rsync
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

# FUNCIÓN CORREGIDA - Sin auto-eliminación prematura
programar_transferencia_remota() {
    local archivo_backup="$1"
    local delay_minutos="${2:-$RSYNC_DELAY_MINUTOS}"
    
    if [ "$REMOTE_BACKUP_ENABLED" != "true" ]; then
        return 0
    fi
    
    if [ ! -f "$archivo_backup" ]; then
        echo "ERROR: Archivo no encontrado para transferencia: $archivo_backup" >> /var/log/backups.log
        return 1
    fi
    
    local nombre_archivo=$(basename "$archivo_backup")
    
    # Verificar que el servicio atd esté activo
    if ! systemctl is-active --quiet atd 2>/dev/null; then
        echo "ERROR: Servicio 'atd' no está activo. No se puede programar transferencia." >> /var/log/backups.log
        return 1
    fi
    
    # Verificar clave SSH
    if [ ! -f "$SSH_KEY" ]; then
        echo "ERROR: Clave SSH no encontrada en $SSH_KEY" >> /var/log/backups.log
        return 1
    fi
    
    # Verificar permisos de clave SSH
    if [ "$(stat -c %a "$SSH_KEY" 2>/dev/null)" != "600" ]; then
        echo "ADVERTENCIA: Permisos de clave SSH incorrectos. Ajustando a 600..." >> /var/log/backups.log
        chmod 600 "$SSH_KEY"
    fi
    
    # Crear script temporal en /tmp (más confiable para at)
    local temp_script
    temp_script=$(mktemp /tmp/rsync_backup_XXXXXX.sh)
    
    # Script con auto-limpieza AL FINAL de la ejecución
    cat > "$temp_script" << SCRIPT_EOF
#!/bin/bash
# Script temporal para transferencia rsync
# Auto-eliminación al finalizar

LOG_FILE="/var/log/backups.log"
BACKUP_FILE="$archivo_backup"
REMOTE_USER="$REMOTE_BACKUP_USER"
REMOTE_HOST="$REMOTE_BACKUP_HOST"
REMOTE_DIR="$REMOTE_BACKUP_DIR"
SSH_KEY="$SSH_KEY"

echo "\$(date): [AT-TRANSFER] Iniciando transferencia programada de $nombre_archivo" >> "\$LOG_FILE"

# Verificar que el archivo todavía existe
if [ ! -f "\$BACKUP_FILE" ]; then
    echo "\$(date): [AT-TRANSFER] ERROR: Archivo local desapareció: $nombre_archivo" >> "\$LOG_FILE"
    rm -f "$temp_script"
    exit 1
fi

# Verificar conectividad con el servidor remoto
if ! ssh -i "\$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "\$REMOTE_USER@\$REMOTE_HOST" "echo 'Conectado'" &>/dev/null; then
    echo "\$(date): [AT-TRANSFER] ERROR: No hay conectividad con servidor remoto" >> "\$LOG_FILE"
    rm -f "$temp_script"
    exit 1
fi

# Realizar transferencia
if /usr/bin/rsync -avz -e "ssh -i \$SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \\
    "\$BACKUP_FILE" \\
    "\$REMOTE_USER@\$REMOTE_HOST:\$REMOTE_DIR/" >> "\$LOG_FILE" 2>&1; then
    echo "\$(date): [AT-TRANSFER] TRANSFERENCIA EXITOSA: $nombre_archivo" >> "\$LOG_FILE"
else
    echo "\$(date): [AT-TRANSFER] ERROR en transferencia: $nombre_archivo" >> "\$LOG_FILE"
fi

# AUTO-LIMPIEZA: Eliminar script temporal AL FINAL
rm -f "$temp_script"
SCRIPT_EOF
    
    chmod +x "$temp_script"
    
    # Programar con at
    local tiempo_at="now + $delay_minutos minutes"
    if echo "$temp_script" | at "$tiempo_at" 2>/dev/null; then
        local job_id=$(atq | head -n 1 | awk '{print $1}')
        echo "✅ Transferencia remota programada. Job ID: $job_id" >> /var/log/backups.log
        return 0
    else
        echo "❌ ERROR: No se pudo programar transferencia con at" >> /var/log/backups.log
        rm -f "$temp_script"
        return 1
    fi
}

# Función para probar conexión remota
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


# Función para configurar respaldo remoto (MODIFICADA)
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
                    actualizar_configuracion "REMOTE_BACKUP_ENABLED" "false"
                    echo "Respaldo remoto DESACTIVADO"
                else
                    actualizar_configuracion "REMOTE_BACKUP_ENABLED" "true"
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
                echo
                echo "Archivo de configuración: $CONFIG_FILE"
                ;;
            4)
                echo -n "Nuevo delay en minutos (actual: $RSYNC_DELAY_MINUTOS): "
                read nuevo_delay
                if [[ "$nuevo_delay" =~ ^[0-9]+$ ]] && [ "$nuevo_delay" -gt 0 ]; then
                    actualizar_configuracion "RSYNC_DELAY_MINUTOS" "$nuevo_delay"
                    echo "Delay de transferencia actualizado a $RSYNC_DELAY_MINUTOS minutos"
                else
                    echo "Error: Debe ingresar un número positivo"
                fi
                ;;
            5)
                echo "Configuración de hora del backup automático"
                echo "Hora actual: $(get_cron_hora_completa)"
                echo
                
                # Configurar hora
                echo -n "Nueva hora (0-23, actual: $CRON_HORA): "
                read nueva_hora
                if [[ "$nueva_hora" =~ ^[0-9]+$ ]] && [ "$nueva_hora" -ge 0 ] && [ "$nueva_hora" -le 23 ]; then
                    actualizar_configuracion "CRON_HORA" "$nueva_hora"
                    echo "Hora actualizada a $nueva_hora"
                else
                    echo "Error: Hora debe ser entre 0 y 23"
                    # Si la hora es inválida, preguntar si quiere continuar
                    echo -n "¿Continuar configurando los minutos? (s/n): "
                    read continuar
                    if [ "$continuar" != "s" ]; then
                        continue
                    fi
                fi
                
                # Configurar minuto
                echo -n "Nuevo minuto (0-59, actual: $CRON_MINUTO): "
                read nuevo_minuto
                if [[ "$nuevo_minuto" =~ ^[0-9]+$ ]] && [ "$nuevo_minuto" -ge 0 ] && [ "$nuevo_minuto" -le 59 ]; then
                    actualizar_configuracion "CRON_MINUTO" "$nuevo_minuto"
                    echo "Minuto actualizado a $nuevo_minuto"
                else
                    echo "Error: Minuto debe ser entre 0 y 59"
                fi
                
                echo "Hora de backup actualizada a: $(get_cron_hora_completa)"
                echo "$(date): Hora de backup cambiada a $(get_cron_hora_completa)" >> /var/log/backups.log
                
                # Si el backup automático está activo, actualizar cron
                if backup_automatico_activo; then
                    echo "Actualizando programación en cron..."
                    toggle_backup_automatico  # Desactivar
                    toggle_backup_automatico  # Reactivar con nueva hora
                fi
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

#funcion para crear el directorio dir_backup si no existe
crear_dir_backup(){
    # si no existe un directorio (dir_backup) entonces lo crea
    # el -d verifica si es un directorio 
    if [ ! -d "$dir_backup" ]
    then
    mkdir -p "$dir_backup"
    chmod 700 "$dir_backup"
    echo "Directorio de backups creado: $dir_backup"
    fi

 #***** si no existe el archivo de log, lo creamo
    if [ ! -f "/var/log/backups.log" ]; then
        touch "/var/log/backups.log"
        chmod 644 "/var/log/backups.log"
    fi
    
    #***** crear directorio de configuracion si no existe
    if [ ! -d "/etc/backup-script" ]; then
        mkdir -p "/etc/backup-script"
        chmod 700 "/etc/backup-script"
    fi
    
    #***** crear archivo de lista de backups automaticos si no existe
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

# se encarga de verificar si el backup esta up and running :D, crontab -l te da una lista con las tareas Cron actuales y busca alguna linea que contenga la ruta del script ( grep te devuelve 0 (true) si no la encuentra y 1 (false) si la encuentra)
backup_automatico_activo(){
    crontab -l 2>/dev/null | grep -q "$Delta"
}

# funcion para mostrar el menu
menu_alpha(){
    clear # clear al principio porque nadie quiere que le salga un menu con la pantalla llena de basura *thumbs up*
    echo "=== GESTOR DE BACKUPS ==="
    echo "1. Crear backup manual"
    
    # agarrando la funcion BAC decimos de una manera bonita si esta activo o no
    if backup_automatico_activo; then
        echo "2. DESACTIVAR backup diario automático  [ACTIVO]"
    else
        echo "2. ACTIVAR backup diario automático   [INACTIVO]"
    fi
    echo "3. Restaurar backup"
    echo "4. Gestionar lista de backups automáticos"
    echo "5. Configurar respaldo remoto"
    echo "6. Probar backup automático (ejecuta ahora)"
    echo "7. Verificar dependencias del sistema"
    echo "0. Salir"
    echo
    echo -n "Seleccione opción (0 para salir): "
}

# bubbles burried in this jungle
# lo mismo que hicimos en admUsuario
# **investigar id, tambien se pueda hacer con grep -q "^${usuario}:" /etc/passwd
usuario_existe() { 
    local usuario="$1"
    id "$usuario" &>/dev/null
}

# Función para verificar si un grupo existe
# usa getent group que busca en la base de datos de grupos del sistema
grupo_existe() {
    local grupo="$1"
    getent group "$grupo" &>/dev/null
}

# Función para obtener los usuarios de un grupo
obtener_usuarios_de_grupo() {
    local grupo="$1"
    # getent group grupo | cut -d: -f4 te da la lista de usuarios separados por comas
    # tr ',' '\n' convierte las comas en saltos de linea para tener un usuario por linea
    getent group "$grupo" | cut -d: -f4 | tr ',' '\n'
}

#***** funcion para leer entrada con opcion de cancelar
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

#***** funcion para mostrar menu de gestion de lista automatica
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

#***** funcion para ver la lista actual de backups automaticos
ver_lista_backup_auto() {
    echo "=== LISTA ACTUAL DE BACKUPS AUTOMÁTICOS ==="
    if [ ! -s "$backup_list" ]; then
        echo "La lista está vacía."
        echo "Los backups automáticos no se ejecutarán hasta que añada elementos."
    else
        # Mostrar solo lineas que no son comentarios y no están vacías
        grep -v '^#' "$backup_list" | grep -v '^$' | nl -w 2 -s '. '
    fi
    echo
}

#***** funcion para añadir usuario a la lista de backups automaticos
añadir_usuario_backup_auto() {
    if ! leer_con_cancelar "Ingrese nombre de usuario a añadir" usuario; then
        return 1
    fi
    
    if usuario_existe "$usuario"; then
        # Verificar si el usuario ya está en la lista
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

#***** funcion para añadir grupo a la lista de backups automaticos
añadir_grupo_backup_auto() {
    if ! leer_con_cancelar "Ingrese nombre del grupo a añadir" grupo; then
        return 1
    fi
    
    if grupo_existe "$grupo"; then
        # Verificar si el grupo ya está en la lista
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

#***** funcion para eliminar elemento de la lista de backups automaticos
eliminar_elemento_backup_auto() {
    ver_lista_backup_auto
    
    if [ ! -s "$backup_list" ]; then
        return 1
    fi
    
    echo
    if ! leer_con_cancelar "Ingrese el número del elemento a eliminar" numero; then
        return 1
    fi
    
    # Obtener el elemento a eliminar
    elemento=$(grep -v '^#' "$backup_list" | grep -v '^$' | sed -n "${numero}p")
    
    if [ -z "$elemento" ]; then
        echo "Número inválido."
        return 1
    fi
    
    echo "¿Eliminar '$elemento' de la lista?"
    echo -n "Confirmar (s/n): "
    read confirmacion
    
    if [ "$confirmacion" = "s" ]; then
        # Crear archivo temporal sin el elemento
        temp_file=$(mktemp)
        grep -v "^$elemento$" "$backup_list" > "$temp_file"
        mv "$temp_file" "$backup_list"
        echo "Elemento '$elemento' eliminado."
    else
        echo "Operación cancelada."
    fi
}

#***** funcion para gestionar la lista de backups automaticos
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

# CORREGIDA: Función para crear backup de grupo con contador correcto
crear_backup_grupo(){
    if ! leer_con_cancelar "Ingrese nombre del grupo" grupo; then
        return 1
    fi
    
    if grupo_existe "$grupo"; then
        fecha=$(date '+%Y%m%d_%H%M%S')
        
        echo "Creando backup del grupo: $grupo"
        echo "Usuarios en el grupo:"
        
        # Contador para usuarios procesados - CORREGIDO: usar archivo temporal para el contador
        local temp_counter=$(mktemp)
        echo "0" > "$temp_counter"
        
        # Obtener usuarios del grupo y crear backup INDIVIDUAL para cada uno
        # CORREGIDO: Usar while read sin pipeline para mantener el contexto
        while IFS= read -r usuario; do
            if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    echo "  - Creando backup de: $usuario"
                    archivo_backup="${dir_backup}/backup_${usuario}_grupo_${fecha}.tar.bz2"
                    
                    # Crear backup individual del usuario
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null
                    then
                        echo "    Backup creado: $(basename "$archivo_backup")"
                        echo "$(date): Backup manual de grupo $grupo - usuario $usuario - $archivo_backup" >> /var/log/backups.log
                        # Incrementar contador
                        local current_count=$(cat "$temp_counter")
                        echo $((current_count + 1)) > "$temp_counter"
                        # Respaldo remoto programado con at (método simplificado)
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

                if usuario_existe "$usuario" 
                then
                    #getent (get entry) te da las entradas de datos del sistema
                    #lo deberiamos usar por el tema de backups entre maquinas (el getent), si no se deberia usar grep 
                    #
                    home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                    
                    #Creamos el nombre del archivo de backup
                    #Guardamos una personalizacion del comando date en una variable fecha 
                    #Lo guardamos sin espacios 
                    fecha=$(date '+%Y%m%d_%H%M%S')
                    archivo_backup="/var/users_backups/backup_${usuario}_${fecha}.tar.bz2"
                    
                    # Creando el backup
                    # tar empaqueta lo que esta en la var archivo_backup, crea un nuevo arch con -c, con j lo comprimimos con bzip2, y -f le decimos el nombre del arch 
                    echo "Creando backup de $home_dir"
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                        echo "Backup creado: $archivo_backup"
                        echo "$(date): Backup manual de $usuario - $archivo_backup" >> /var/log/backups.log
                        # Respaldo remoto programado con at (método simplificado)
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

# FUNCIÓN BACKUP_DIARIO SIMPLIFICADA - SIN LOCKFILE
backup_diario(){
    local fecha=$(date '+%Y%m%d')
    local usuarios_procesados=0
    local archivos_creados=()
    local exit_code=0

    echo "🔄 [BACKUP-DIARIO] Iniciando backup automático - PID: $$" >> /var/log/backups.log

    # Validar configuración crítica
    if [ -z "$CRON_HORA" ] || [ -z "$CRON_MINUTO" ]; then
        echo "❌ ERROR: Variables CRON_HORA o CRON_MINUTO no configuradas" >> /var/log/backups.log
        return 1
    fi

    # Verificar si el archivo de lista existe y tiene contenido
    if [ ! -f "$backup_list" ] || [ ! -s "$backup_list" ]; then
        echo "ℹ️  [BACKUP-DIARIO] Lista vacía, no hay backups para realizar" >> /var/log/backups.log
        return 0
    fi

    # Leer la lista de backups automáticos
    while IFS= read -r linea; do
        # Saltar líneas vacías o comentarios
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue
        
        if [[ "$linea" =~ ^@ ]]; then
            # Es un grupo
            grupo="${linea#@}"
            if grupo_existe "$grupo"; then
                echo "👥 [BACKUP-DIARIO] Procesando grupo: $grupo" >> /var/log/backups.log
                
                # Evitar process substitution - usar método compatible
                local usuarios_del_grupo
                usuarios_del_grupo=$(obtener_usuarios_de_grupo "$grupo")
                
                while IFS= read -r usuario; do
                    if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                        home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                        if [ -d "$home_dir" ]; then
                            archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                            if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                                echo "✅ [BACKUP-DIARIO] Backup creado: $usuario" >> /var/log/backups.log
                                ((usuarios_procesados++))
                                archivos_creados+=("$archivo_backup")
                            else
                                echo "❌ [BACKUP-DIARIO] Error creando backup: $usuario" >> /var/log/backups.log
                                exit_code=1
                            fi
                        fi
                    fi
                done <<< "$usuarios_del_grupo"
            else
                echo "❌ [BACKUP-DIARIO] Grupo no existe: $grupo" >> /var/log/backups.log
                exit_code=1
            fi
        else
            # Es un usuario individual
            usuario="$linea"
            if usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                        echo "✅ [BACKUP-DIARIO] Backup creado: $usuario" >> /var/log/backups.log
                        ((usuarios_procesados++))
                        archivos_creados+=("$archivo_backup")
                    else
                        echo "❌ [BACKUP-DIARIO] Error creando backup: $usuario" >> /var/log/backups.log
                        exit_code=1
                    fi
                fi
            else
                echo "❌ [BACKUP-DIARIO] Usuario no existe: $usuario" >> /var/log/backups.log
                exit_code=1
            fi
        fi
    done < "$backup_list"

    # Programar transferencias remotas
    if [ ${#archivos_creados[@]} -gt 0 ] && [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
        echo "📤 [BACKUP-DIARIO] Programando ${#archivos_creados[@]} transferencias remotas" >> /var/log/backups.log
        for archivo in "${archivos_creados[@]}"; do
            if ! programar_transferencia_remota "$archivo" "$RSYNC_DELAY_MINUTOS"; then
                echo "❌ [BACKUP-DIARIO] Error programando transferencia: $(basename "$archivo")" >> /var/log/backups.log
                exit_code=1
            fi
        done
    fi

    echo "✅ [BACKUP-DIARIO] Completado: $usuarios_procesados usuarios procesados" >> /var/log/backups.log
    
    return $exit_code
}

# CORREGIDA: función para activar/desactivar el backup automatico con validaciones
toggle_backup_automatico(){
    if backup_automatico_activo; then
        # DESACTIVAR - eliminar de crontab
        (crontab -l 2>/dev/null | grep -v "$Delta") | crontab -
        echo "🔴 Backup automático DESACTIVADO"
        echo "$(date): 🔴 Backup automático desactivado" >> /var/log/backups.log
    else
        # Verificar dependencias antes de activar
        echo "Verificando dependencias antes de activar backup automático..." >> /var/log/backups.log
        if ! verificar_dependencias; then
            echo "❌ No se puede activar backup automático debido a errores en dependencias"
            echo "❌ Revisa /var/log/backups.log para más detalles"
            return 1
        fi
        
        # Mostrar advertencia si la lista está vacía
        if [ ! -f "$backup_list" ] || ! grep -v '^#' "$backup_list" | grep -v '^$' | read; then
            echo "⚠️  ¡ADVERTENCIA: La lista de backups automáticos está vacía!"
            echo "   No se realizarán backups hasta que añada usuarios/grupos."
            echo "   Puede gestionar la lista en la opción 4 del menú principal."
            echo
        fi
        
        # Programar ejecución DIARIA a la hora específica
        local entrada_cron="$CRON_MINUTO $CRON_HORA * * * $Delta automatico"
        (crontab -l 2>/dev/null; echo "$entrada_cron") | crontab -
        
        echo "🟢 Backup automático ACTIVADO"
        echo "   Se ejecutará diariamente a las $(get_cron_hora_completa)"
        echo "   Las transferencias remotas se programarán con at"
        echo "$(date): 🟢 Backup automático activado - $entrada_cron" >> /var/log/backups.log
        
        # Mostrar entrada de cron actual
        echo
        echo "📅 Entrada de cron actual:"
        crontab -l | grep "$Delta"
    fi
}

# funcion para restaurar backups existentes DUH
restaurar_backup(){
    while true; do
        echo "Backups disponibles:"
        # -1 te lo da en lista, con un archivo por linea 
        # nl = number lines se encarga de enumerar las lineas, -w 2 te da un ancho de dos digitos para los numeros -s es el separador despues del num, que en este caso es un . 
        ls -1 "$dir_backup"/*.tar.bz2 2>/dev/null | nl -w 2 -s '. '

        # $? guarda la salida del utimo comando, osea el ls que acabamos de hacer, si no hay backups retorna 1 y termina la ejecuccion
        if [ $? -ne 0 ]
        then
            echo "No hay backups disponibles."
            echo "Presione Enter para continuar..."
            read
            return 1
        fi

        echo
        echo -n "Seleccione el numero del backup a restaurar (0 para volver): "
        read numero 

        # Opción para volver
        if [ "$numero" = "0" ]; then
            echo "Volviendo al menú principal..."
            return 1
        fi

        # con ls -1 volvemos a listar los archivos de dir_backup 
        # p = print no es una p de caracter
        # sed nos muestra todas las lineas con -n no muestra nada, solo el numero que eligio el usuario (el directorio entero )
        archivo_backup=$(ls -1 "$dir_backup"/*.tar.bz2 | sed -n "${numero}p")

        # si archivo backup esta vacio o es invalido entonces se termina la ejecucion
        if [ -z "$archivo_backup" ]
        then
            echo "Numero invalido"
            continue
        fi
        
        # usamos basename solo para agarrar el nombre del backup que queremos EJ: backup_user.tar.bz2 envez de la direccion entera
        nombre_archivo=$(basename "$archivo_backup")
        
        # CORREGIDO: Extraemos el usuario de manera más inteligente
        # Para backup individual: backup_alumno_20241210_143022.tar.bz2 -> usuario=alumno
        # Para backup de grupo: backup_alumno_grupo_20241210_143022.tar.bz2 -> usuario=alumno
        if [[ "$nombre_archivo" =~ ^backup_([^_]+)_ ]]; then
            usuario="${BASH_REMATCH[1]}"
        else
            echo "Formato de archivo de backup no reconocido: $nombre_archivo"
            continue
        fi

        echo "usuario del backup: $usuario"

        # usando la funcion de usr_exst determina que si dicho usuario no existe se termina la ejecucion 
        if ! usuario_existe "$usuario"
        then
            echo "ERROR: UNF; el usuario $usuario no existe en el sistema"
            echo "Presione Enter para continuar..."
            read
            continue
        fi

        #home destino es el directorio de usuario de un usuario, lo agarramos haciendole un cut a la linea passwd del usuario en el campo 6 que es donde esta el dir de usuario
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

        #crea un directorio temporal en /tmp
        temp_dir=$(mktemp -d)

        echo "Restaurando backup..."

        # extraemos el backup en el directorio temporal
        if tar -xjf "$archivo_backup" -C "$temp_dir" 2>/dev/null
            then
            #Buscamos donde estan los archivos de usuario
            #aca buscamos si esta con /home/y el usuario
            if [ -d "$temp_dir/home/$usuario" ]
            then
            dir_origen="$temp_dir/home/$usuario" 
            #aca buscamos si esta solo con el usuario
            elif [ -d "$temp_dir/$usuario" ]
            then
            dir_origen="$temp_dir/$usuario"
            #y aca si esta en archivos sueltos
            else
            dir_origen="$temp_dir/$usuario"
            fi

            # aca copiamos los archivos al origen real
            # primero copiamos las carpetas y archivos visivles y luego hacemos lo mismo con las invisibles
            echo "copiando archivos a $home_destino..."
            #*************investigar en mayor Profundidad 
            #************************** rsync sincroniza directorios de manera eficiente
            rsync -av "$dir_origen/" "$home_destino"/ 2>/dev/null

            # reparamos los permisos con un change owner recursivo en todo el directorio
            chown -R "$usuario:$usuario" "$home_destino"

            echo "Restauración completada"

            # Limpiamos temp_dir y borramos todo lo que tiene dentro
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
# Cargar configuración persistente
cargar_configuracion

# punto de entrada del script - verifica usuario y crea directorios necesarios
check_user
crear_dir_backup

# ***** Manejo de modos de ejecución
if [ "$1" = "automatico" ]; then
    # Modo automático desde cron - CORREGIDO: ejecución diaria única
    {
        echo "================================================"
        echo "$(date): [CRON] INICIANDO BACKUP AUTOMÁTICO DIARIO"
        echo "================================================"
        
        # Verificar que los archivos necesarios existen
        echo "Verificando archivos necesarios..."
        if [ ! -f "$backup_list" ]; then
            echo "ERROR: No existe el archivo de lista: $backup_list"
            exit 1
        fi
        
        if [ ! -s "$backup_list" ]; then
            echo "INFO: Lista de backups vacía, no hay nada que hacer"
            exit 0
        fi
        
        # Ejecutar backup diario
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

else
    # Modo interactivo normal - ELIMINADA la verificación horaria automática
    # No se verifica la hora para evitar duplicación con cron
    :
fi

while true; do
    menu_alpha
    read opcion

    case $opcion in
        1)
            # crear backup directamente sin lock
            crear_backup
            ;;
        2)
            # No necesita lock porque solo modifica crontab
            toggle_backup_automatico
            ;;
        3)
            # restaurar backup directamente sin lock
            restaurar_backup
            ;;
        4)
            gestionar_backup_auto
            ;;
        5)
            configurar_respaldo_remoto
            ;;
        6)
            echo "Ejecutando backup automático de prueba..."
            backup_diario
            ;;
        7)
            echo "Ejecutando verificación de dependencias..."
            verificar_dependencias
            echo "Verificación completada. Revisa /var/log/backups.log"
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