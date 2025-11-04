#!/bin/bash

# =============================================
# CONFIGURACIÓN Y VARIABLES GLOBALES
# =============================================

# Archivo de configuración persistente donde se guardan los ajustes del usuario
CONFIG_FILE="/etc/backup-script/backup-config.conf"

# Configuración por defecto del sistema de backups
CRON_HORA="3"                           # Hora programada para backup automático (formato 24h)
CRON_MINUTO="10"                        # Minuto programado para backup automático
RSYNC_DELAY_MINUTOS="5"                 # Tiempo de espera antes de transferencia remota
REMOTE_BACKUP_ENABLED="true"            # Habilitar/deshabilitar respaldo remoto
REMOTE_BACKUP_USER="respaldo_user"      # Usuario para conexión SSH remota
REMOTE_BACKUP_HOST="192.168.0.93"       # Dirección del servidor de backups remoto
REMOTE_BACKUP_DIR="/backups/usuarios"   # Directorio destino en servidor remoto
SSH_KEY="/root/.ssh/backup_key"         # Ruta de la clave SSH para autenticación

# Variables de rutas y directorios del sistema
dir_backup="/var/users_backups"         # Directorio local donde se almacenan los backups
Delta=$(realpath "$0")                  # Ruta absoluta del script actual para referencias
backup_list="/etc/backup-script/auto-backup-list.conf"  # Lista de usuarios/grupos para backup automático

# =============================================
# FUNCIONES DE CONFIGURACIÓN Y SISTEMA
# =============================================

# Verifica que el script se ejecute con privilegios de root
# Esto es necesario para acceder a directorios de sistema y modificar crontab
check_user() {
    if [ "$(whoami)" != "root" ]; then
        echo "ERROR: Este script debe ejecutarse con sudo o como root"
        echo "Uso: sudo $0"
        exit 1
    fi
}

# Carga la configuración desde archivo persistente o crea una nueva con valores por defecto
cargar_configuracion() {
    if [ -f "$CONFIG_FILE" ]; then
        # source ejecuta el archivo de configuración como si fuera parte del script
        source "$CONFIG_FILE"
        echo "Configuración cargada desde $CONFIG_FILE" >> /var/log/backups.log
    else
        # Si no existe el archivo, guarda la configuración por defecto
        guardar_configuracion
    fi
}

# Guarda la configuración actual en archivo persistente para mantenerla entre ejecuciones
guardar_configuracion() {
    # mkdir -p crea el directorio solo si no existe
    mkdir -p "/etc/backup-script"
    
    # cat con here-document escribe múltiples líneas en el archivo de configuración
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

    # chmod 600 asegura que solo root pueda leer/escribir el archivo de configuración
    chmod 600 "$CONFIG_FILE"
    echo "Configuración guardada en $CONFIG_FILE" >> /var/log/backups.log
}

# Actualiza una variable de configuración y guarda los cambios en archivo
actualizar_configuracion() {
    local variable="$1"
    local valor="$2"
    
    # eval permite asignar dinámicamente el valor a la variable especificada
    eval "$variable=\"$valor\""
    
    # Guarda los cambios en el archivo de configuración persistente
    guardar_configuracion
}

# =============================================
# FUNCIONES DE UTILIDAD Y FORMATO
# =============================================

# Convierte hora en formato 24h a formato AM/PM legible
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

# Obtiene la hora completa formateada para mostrar al usuario
get_cron_hora_completa() {
    local hora_ampm=$(formato_am_pm "$CRON_HORA")
    # printf "%02d" asegura que los minutos siempre tengan 2 dígitos (ej: 05 en vez de 5)
    local minuto_formateado=$(printf "%02d" "$CRON_MINUTO")
    echo "${CRON_HORA}:${minuto_formateado} ($hora_ampm)"
}

# Verifica todas las dependencias necesarias para el funcionamiento del sistema
verificar_dependencias() {
    local errores=0
    
    echo "Verificando dependencias del sistema..." >> /var/log/backups.log
    
    # systemctl is-active verifica si el servicio atd está ejecutándose
    # atd es necesario para programar transferencias remotas retardadas
    if ! systemctl is-active --quiet atd 2>/dev/null; then
        echo "SERVICIO ATD: No está activo. Ejecuta: sudo systemctl enable atd && sudo systemctl start atd" >> /var/log/backups.log
        ((errores++))
    else
        echo "SERVICIO ATD: Activo" >> /var/log/backups.log
    fi
    
    # Verifica que exista la clave SSH y tenga los permisos correctos (600)
    if [ ! -f "$SSH_KEY" ]; then
        echo "CLAVE SSH: No encontrada en $SSH_KEY" >> /var/log/backups.log
        ((errores++))
    elif [ "$(stat -c %a "$SSH_KEY" 2>/dev/null)" != "600" ]; then
        echo "CLAVE SSH: Permisos incorrectos. Ajustando..." >> /var/log/backups.log
        chmod 600 "$SSH_KEY"
        echo "CLAVE SSH: Permisos corregidos" >> /var/log/backups.log
    else
        echo "CLAVE SSH: Encontrada y con permisos correctos" >> /var/log/backups.log
    fi
    
    # Verifica conectividad con el servidor remoto si está habilitado el respaldo remoto
    if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
        # ssh con BatchMode=yes evita prompts interactivos, ConnectTimeout=5 limita el tiempo de espera
        if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo 'OK'" &>/dev/null; then
            echo "CONECTIVIDAD: No se puede conectar a $REMOTE_BACKUP_HOST" >> /var/log/backups.log
            ((errores++))
        else
            echo "CONECTIVIDAD: Conexión remota funcionando" >> /var/log/backups.log
        fi
    fi
    
    # Verifica que el script actual tenga permisos de ejecución
    if [ ! -x "$Delta" ]; then
        echo "PERMISOS SCRIPT: No es ejecutable. Ajustando..." >> /var/log/backups.log
        chmod +x "$Delta"
        echo "PERMISOS SCRIPT: Corregidos" >> /var/log/backups.log
    else
        echo "PERMISOS SCRIPT: Ejecutable" >> /var/log/backups.log
    fi
    
    # Resume el resultado de la verificación de dependencias
    if [ $errores -eq 0 ]; then
        echo "TODAS LAS DEPENDENCIAS: Verificadas correctamente" >> /var/log/backups.log
    else
        echo "SE ENCONTRARON $errores ERROR(ES) en las dependencias" >> /var/log/backups.log
    fi
    
    return $errores
}

# =============================================
# FUNCIONES DE BACKUP REMOTO Y TRANSFERENCIA
# =============================================

# Programa una transferencia remota retardada usando el comando 'at'
programar_transferencia_remota() {
    local archivo_backup="$1"
    local delay_minutos="${2:-$RSYNC_DELAY_MINUTOS}"
    
    # Si el respaldo remoto está deshabilitado, sale silenciosamente
    if [ "$REMOTE_BACKUP_ENABLED" != "true" ]; then
        return 0
    fi
    
    # Verifica que el archivo de backup local exista antes de programar transferencia
    if [ ! -f "$archivo_backup" ]; then
        echo "ERROR: Archivo no encontrado para transferencia: $archivo_backup" >> /var/log/backups.log
        return 1
    fi
    
    local nombre_archivo=$(basename "$archivo_backup")
    
    # Verifica que el servicio atd esté activo para programar trabajos
    if ! systemctl is-active --quiet atd 2>/dev/null; then
        echo "ERROR: Servicio 'atd' no está activo. No se puede programar transferencia." >> /var/log/backups.log
        return 1
    fi
    
    # mktemp crea un archivo temporal único para el script de transferencia
    local temp_script
    temp_script=$(mktemp /tmp/rsync_backup_XXXXXX.sh)
    
    # Genera un script temporal que se ejecutará mediante 'at'
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

# Verifica que el archivo todavía exista al momento de la ejecución
if [ ! -f "\$BACKUP_FILE" ]; then
    echo "\$(date): [AT-TRANSFER] ERROR: Archivo local desapareció: $nombre_archivo" >> "\$LOG_FILE"
    rm -f "$temp_script"
    exit 1
fi

# Realiza la transferencia usando rsync sobre SSH
if /usr/bin/rsync -avz -e "ssh -i \$SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \\
    "\$BACKUP_FILE" \\
    "\$REMOTE_USER@\$REMOTE_HOST:\$REMOTE_DIR/" >> "\$LOG_FILE" 2>&1; then
    echo "\$(date): [AT-TRANSFER] TRANSFERENCIA EXITOSA: $nombre_archivo" >> "\$LOG_FILE"
else
    echo "\$(date): [AT-TRANSFER] ERROR en transferencia: $nombre_archivo" >> "\$LOG_FILE"
fi

# Auto-limpieza: elimina el script temporal después de ejecutarse
rm -f "$temp_script"
SCRIPT_EOF
    
    # Hace el script temporal ejecutable
    chmod +x "$temp_script"
    
    # Programa la ejecución del script con 'at' después del delay especificado
    local tiempo_at="now + $delay_minutos minutes"
    if echo "$temp_script" | at "$tiempo_at" 2>/dev/null; then
        echo "Transferencia remota programada: $nombre_archivo" >> /var/log/backups.log
        return 0
    else
        echo "ERROR: No se pudo programar transferencia con at" >> /var/log/backups.log
        rm -f "$temp_script"
        return 1
    fi
}

# Prueba la conexión con el servidor remoto de backups
probar_conexion_remota() {
    echo "Probando conexión con servidor remoto..."
    
    # Intenta ejecutar un comando simple en el servidor remoto
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo 'Conexión exitosa'" 2>/dev/null; then
        echo "Conexión remota funcionando correctamente"
        return 0
    else
        echo "Error en conexión remota"
        return 1
    fi
}

# =============================================
# FUNCIONES DE GESTIÓN DE DIRECTORIOS Y ARCHIVOS
# =============================================

# Crea todos los directorios y archivos necesarios para el funcionamiento del sistema
crear_dir_backup(){
    # Crea el directorio principal de backups si no existe
    if [ ! -d "$dir_backup" ]; then
        mkdir -p "$dir_backup"
        chmod 700 "$dir_backup"  # Solo root puede acceder
        echo "Directorio de backups creado: $dir_backup"
    fi

    # Crea el archivo de log si no existe
    if [ ! -f "/var/log/backups.log" ]; then
        touch "/var/log/backups.log"
        chmod 644 "/var/log/backups.log"  # Lectura para todos, escritura solo owner
    fi
    
    # Crea el directorio de configuración si no existe
    if [ ! -d "/etc/backup-script" ]; then
        mkdir -p "/etc/backup-script"
        chmod 700 "/etc/backup-script"  # Solo root puede acceder
    fi
    
    # Crea el archivo de lista de backups automáticos si no existe
    if [ ! -f "$backup_list" ]; then
        touch "$backup_list"
        chmod 600 "$backup_list"  # Solo root puede leer/escribir
        # Agrega encabezado y ejemplos al archivo
        echo "# Lista de usuarios y grupos para backup automatico" > "$backup_list"
        echo "# Formato: usuario o @grupo" >> "$backup_list"
        echo "# Ejemplo:" >> "$backup_list"
        echo "# usuario1" >> "$backup_list"
        echo "# @developers" >> "$backup_list"
    fi
}

# =============================================
# FUNCIONES DE VERIFICACIÓN DE USUARIOS Y GRUPOS
# =============================================

# Verifica si un usuario existe en el sistema
# id command retorna 0 si el usuario existe, 1 si no existe
usuario_existe() { 
    local usuario="$1"
    id "$usuario" &>/dev/null
}

# Verifica si un grupo existe en el sistema usando getent
grupo_existe() {
    local grupo="$1"
    getent group "$grupo" &>/dev/null
}

# Obtiene la lista de usuarios pertenecientes a un grupo
obtener_usuarios_de_grupo() {
    local grupo="$1"
    # getent group obtiene la entrada del grupo, cut extrae el campo 4 (miembros)
    # tr convierte las comas en saltos de línea para procesar cada usuario por separado
    getent group "$grupo" | cut -d: -f4 | tr ',' '\n'
}

# =============================================
# FUNCIONES DE INTERFAZ DE USUARIO Y MENÚS
# =============================================

# Lee entrada del usuario con opción de cancelar (0)
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

# Verifica si el backup automático está activo en crontab
backup_automatico_activo(){
    # crontab -l lista las tareas programadas, grep -q busca silenciosamente
    crontab -l 2>/dev/null | grep -q "$Delta"
}

# Muestra el menú principal del sistema
menu_alpha(){
    clear  # Limpia la pantalla para una interfaz limpia
    echo "=== GESTOR DE BACKUPS ==="
    echo "1. Crear backup manual"
    
    # Muestra el estado actual del backup automático
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

# =============================================
# FUNCIONES DE GESTIÓN DE LISTA DE BACKUPS AUTOMÁTICOS
# =============================================

# Muestra el menú de gestión de lista de backups automáticos
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

# Muestra la lista actual de elementos para backup automático
ver_lista_backup_auto() {
    echo "=== LISTA ACTUAL DE BACKUPS AUTOMÁTICOS ==="
    if [ ! -s "$backup_list" ]; then
        echo "La lista está vacía."
        echo "Los backups automáticos no se ejecutarán hasta que añada elementos."
    else
        # grep -v '^#' excluye líneas comentadas, nl enumera las líneas resultantes
        # -w 2 establece ancho de 2 dígitos para números, -s '. ' usa punto como separador
        grep -v '^#' "$backup_list" | grep -v '^$' | nl -w 2 -s '. '
    fi
    echo
}

# Añade un usuario a la lista de backups automáticos
añadir_usuario_backup_auto() {
    if ! leer_con_cancelar "Ingrese nombre de usuario a añadir" usuario; then
        return 1
    fi
    
    if usuario_existe "$usuario"; then
        # Verifica si el usuario ya está en la lista para evitar duplicados
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

# Añade un grupo a la lista de backups automáticos
añadir_grupo_backup_auto() {
    if ! leer_con_cancelar "Ingrese nombre del grupo a añadir" grupo; then
        return 1
    fi
    
    if grupo_existe "$grupo"; then
        grupo_line="@$grupo"
        # Verifica si el grupo ya está en la lista
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

# Elimina un elemento de la lista de backups automáticos
eliminar_elemento_backup_auto() {
    ver_lista_backup_auto
    
    if [ ! -s "$backup_list" ]; then
        return 1
    fi
    
    echo
    if ! leer_con_cancelar "Ingrese el número del elemento a eliminar" numero; then
        return 1
    fi
    
    # Obtiene el elemento específico basado en el número ingresado
    elemento=$(grep -v '^#' "$backup_list" | grep -v '^$' | sed -n "${numero}p")
    
    if [ -z "$elemento" ]; then
        echo "Número inválido."
        return 1
    fi
    
    echo "¿Eliminar '$elemento' de la lista?"
    echo -n "Confirmar (s/n): "
    read confirmacion
    
    if [ "$confirmacion" = "s" ]; then
        # Crea archivo temporal sin el elemento y reemplaza el original
        temp_file=$(mktemp)
        grep -v "^$elemento$" "$backup_list" > "$temp_file"
        mv "$temp_file" "$backup_list"
        echo "Elemento '$elemento' eliminado."
    else
        echo "Operación cancelada."
    fi
}

# Menú principal de gestión de lista de backups automáticos
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

# =============================================
# FUNCIONES DE CREACIÓN DE BACKUPS
# =============================================

# Crea backup de todos los usuarios pertenecientes a un grupo
crear_backup_grupo(){
    if ! leer_con_cancelar "Ingrese nombre del grupo" grupo; then
        return 1
    fi
    
    if grupo_existe "$grupo"; then
        # Genera timestamp único para el backup
        fecha=$(date '+%Y%m%d_%H%M%S')
        
        echo "Creando backup del grupo: $grupo"
        echo "Usuarios en el grupo:"
        
        # Contador temporal para llevar registro de usuarios procesados
        local temp_counter=$(mktemp)
        echo "0" > "$temp_counter"
        
        # Procesa cada usuario del grupo individualmente
        while IFS= read -r usuario; do
            if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    echo "  - Creando backup de: $usuario"
                    archivo_backup="${dir_backup}/backup_${usuario}_grupo_${fecha}.tar.bz2"
                    
                    # Crea backup comprimido del directorio home del usuario
                    if tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null; then
                        echo "    Backup creado: $(basename "$archivo_backup")"
                        echo "$(date): Backup manual de grupo $grupo - usuario $usuario - $archivo_backup" >> /var/log/backups.log
                        # Incrementa el contador de usuarios procesados
                        local current_count=$(cat "$temp_counter")
                        echo $((current_count + 1)) > "$temp_counter"
                        # Programa transferencia remota si está habilitada
                        programar_transferencia_remota "$archivo_backup"
                    else
                        echo "    Error al crear backup de $usuario"
                    fi
                fi
            else
                echo "  - Usuario $usuario no existe, omitiendo"
            fi
        done < <(obtener_usuarios_de_grupo "$grupo")
        
        # Obtiene y muestra el total de usuarios procesados
        local usuarios_procesados=$(cat "$temp_counter")
        rm -f "$temp_counter"
        
        echo "Backup de grupo completado: $usuarios_procesados usuarios procesados"
        
    else
        echo "El grupo $grupo no existe."
        return 1
    fi
}

# Menú principal para creación de backups manuales
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
                    # getent obtiene información del usuario desde bases de datos del sistema
                    home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                    
                    # Genera nombre de archivo con timestamp para evitar colisiones
                    fecha=$(date '+%Y%m%d_%H%M%S')
                    archivo_backup="/var/users_backups/backup_${usuario}_${fecha}.tar.bz2"
                    
                    echo "Creando backup de $home_dir"
                    # tar -cjf crea archivo comprimido: c=crear, j=bzip2, f=archivo
                    if tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null; then
                        echo "Backup creado: $archivo_backup"
                        echo "$(date): Backup manual de $usuario - $archivo_backup" >> /var/log/backups.log
                        # Programa transferencia remota si está habilitada
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

# =============================================
# FUNCIÓN DE BACKUP DIARIO AUTOMÁTICO
# =============================================

# Ejecuta el backup automático diario según la lista configurada
backup_diario(){
    local fecha=$(date '+%Y%m%d_%H%M%S')  # Timestamp único para esta ejecución
    local usuarios_procesados=0
    local archivos_creados=()
    local exit_code=0

    echo "$(date): [BACKUP-DIARIO] Iniciando backup automático - PID: $$" >> /var/log/backups.log
    echo "$(date): [BACKUP-DIARIO] Fecha: $fecha" >> /var/log/backups.log

    # Verifica configuración crítica antes de proceder
    if [ -z "$CRON_HORA" ] || [ -z "$CRON_MINUTO" ]; then
        echo "ERROR: Variables CRON_HORA o CRON_MINUTO no configuradas" >> /var/log/backups.log
        return 1
    fi

    # Verifica que exista la lista de backups y tenga contenido
    if [ ! -f "$backup_list" ]; then
        echo "ERROR: Archivo de lista no encontrado: $backup_list" >> /var/log/backups.log
        return 1
    fi

    if [ ! -s "$backup_list" ]; then
        echo "INFO: Lista vacía, no hay backups para realizar" >> /var/log/backups.log
        return 0
    fi

    echo "INFO: Leyendo lista de backups: $backup_list" >> /var/log/backups.log

    # Procesa cada línea del archivo de lista de backups
    while IFS= read -r linea; do
        # Salta líneas vacías o comentarios
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue
        
        echo "INFO: Procesando línea: $linea" >> /var/log/backups.log

        if [[ "$linea" =~ ^@ ]]; then
            # Es un grupo - procesa todos los usuarios del grupo
            grupo="${linea#@}"
            if grupo_existe "$grupo"; then
                echo "GRUPO: Procesando grupo: $grupo" >> /var/log/backups.log
                
                # Procesa cada usuario del grupo
                while IFS= read -r usuario; do
                    if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                        home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                        if [ -d "$home_dir" ]; then
                            archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                            echo "INFO: Creando backup de $usuario en $archivo_backup" >> /var/log/backups.log
                            
                            # Crea backup comprimido del directorio home
                            if tar -cjf "$archivo_backup" -C / "$home_dir" >> /var/log/backups.log 2>&1; then
                                echo "EXITO: Backup creado: $usuario" >> /var/log/backups.log
                                ((usuarios_procesados++))
                                archivos_creados+=("$archivo_backup")
                                
                                # Programa transferencia remota si está habilitada
                                if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
                                    programar_transferencia_remota "$archivo_backup" "$RSYNC_DELAY_MINUTOS"
                                fi
                            else
                                echo "ERROR: Error creando backup: $usuario" >> /var/log/backups.log
                                exit_code=1
                            fi
                        else
                            echo "ERROR: El directorio home de $usuario no existe: $home_dir" >> /var/log/backups.log
                        fi
                    else
                        echo "ERROR: Usuario $usuario no existe, omitiendo" >> /var/log/backups.log
                    fi
                done < <(obtener_usuarios_de_grupo "$grupo")
            else
                echo "ERROR: Grupo no existe: $grupo" >> /var/log/backups.log
                exit_code=1
            fi
        else
            # Es un usuario individual
            usuario="$linea"
            if usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                    echo "INFO: Creando backup de $usuario en $archivo_backup" >> /var/log/backups.log
                    
                    if tar -cjf "$archivo_backup" -C / "$home_dir" >> /var/log/backups.log 2>&1; then
                        echo "EXITO: Backup creado: $usuario" >> /var/log/backups.log
                        ((usuarios_procesados++))
                        archivos_creados+=("$archivo_backup")
                        
                        if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
                            programar_transferencia_remota "$archivo_backup" "$RSYNC_DELAY_MINUTOS"
                        fi
                    else
                        echo "ERROR: Error creando backup: $usuario" >> /var/log/backups.log
                        exit_code=1
                    fi
                else
                    echo "ERROR: El directorio home de $usuario no existe: $home_dir" >> /var/log/backups.log
                fi
            else
                echo "ERROR: Usuario no existe: $usuario" >> /var/log/backups.log
                exit_code=1
            fi
        fi
    done < "$backup_list"

    echo "EXITO: Completado: $usuarios_procesados usuarios procesados" >> /var/log/backups.log
    
    return $exit_code
}

# =============================================
# FUNCIÓN DE CONFIGURACIÓN DE RESPALDO REMOTO
# =============================================

# Menú de configuración para opciones de respaldo remoto
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
                
                # Configuración de hora
                echo -n "Nueva hora (0-23, actual: $CRON_HORA): "
                read nueva_hora
                if [[ "$nueva_hora" =~ ^[0-9]+$ ]] && [ "$nueva_hora" -ge 0 ] && [ "$nueva_hora" -le 23 ]; then
                    actualizar_configuracion "CRON_HORA" "$nueva_hora"
                    echo "Hora actualizada a $nueva_hora"
                else
                    echo "Error: Hora debe ser entre 0 y 23"
                    echo -n "¿Continuar configurando los minutos? (s/n): "
                    read continuar
                    if [ "$continuar" != "s" ]; then
                        continue
                    fi
                fi
                
                # Configuración de minuto
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
                
                # Si el backup automático está activo, actualiza cron con la nueva hora
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

# =============================================
# FUNCIÓN DE ACTIVACIÓN/DESACTIVACIÓN DE BACKUP AUTOMÁTICO
# =============================================

# Activa o desactiva el backup automático en crontab
toggle_backup_automatico(){
    if backup_automatico_activo; then
        # DESACTIVAR - elimina la entrada del script actual de crontab
        (crontab -l 2>/dev/null | grep -v "$Delta") | crontab -
        echo "Backup automático DESACTIVADO"
        echo "$(date): Backup automático desactivado" >> /var/log/backups.log
    else
        # Verifica dependencias antes de activar
        echo "Verificando dependencias antes de activar backup automático..." >> /var/log/backups.log
        if ! verificar_dependencias; then
            echo "No se puede activar backup automático debido a errores en dependencias"
            echo "Revisa /var/log/backups.log para más detalles"
            return 1
        fi
        
        # Muestra advertencia si la lista está vacía
        if [ ! -f "$backup_list" ] || ! grep -v '^#' "$backup_list" | grep -v '^$' | read; then
            echo "ADVERTENCIA: La lista de backups automáticos está vacía!"
            echo "No se realizarán backups hasta que añada usuarios/grupos."
            echo "Puede gestionar la lista en la opción 4 del menú principal."
            echo
        fi
        
        # Crea entrada de cron para ejecución diaria a la hora especificada
        local entrada_cron="$CRON_MINUTO $CRON_HORA * * * $Delta automatico"
        (crontab -l 2>/dev/null; echo "$entrada_cron") | crontab -
        
        echo "Backup automático ACTIVADO"
        echo "Se ejecutará diariamente a las $(get_cron_hora_completa)"
        echo "Las transferencias remotas se programarán con at"
        echo "$(date): Backup automático activado - $entrada_cron" >> /var/log/backups.log
        
        # Muestra la entrada de cron actual para confirmación
        echo
        echo "Entrada de cron actual:"
        crontab -l | grep "$Delta"
    fi
}

# =============================================
# FUNCIÓN DE RESTAURACIÓN DE BACKUPS
# =============================================

# Restaura un backup seleccionado por el usuario
restaurar_backup(){
    while true; do
        echo "Backups disponibles:"
        # ls -1 lista un archivo por línea, nl enumera con formato bonito
        # -w 2 establece ancho de 2 dígitos, -s '. ' usa punto como separador
        ls -1 "$dir_backup"/*.tar.bz2 2>/dev/null | nl -w 2 -s '. '

        # $? contiene el exit status del último comando (ls)
        # Si no hay backups, ls retorna error y $? será diferente de 0
        if [ $? -ne 0 ]; then
            echo "No hay backups disponibles."
            echo "Presione Enter para continuar..."
            read
            return 1
        fi

        echo
        echo -n "Seleccione el numero del backup a restaurar (0 para volver): "
        read numero 

        # Opción para volver al menú principal
        if [ "$numero" = "0" ]; then
            echo "Volviendo al menú principal..."
            return 1
        fi

        # sed -n "${numero}p" extrae solo la línea correspondiente al número seleccionado
        archivo_backup=$(ls -1 "$dir_backup"/*.tar.bz2 | sed -n "${numero}p")

        if [ -z "$archivo_backup" ]; then
            echo "Numero invalido"
            continue
        fi
        
        # basename extrae solo el nombre del archivo sin la ruta completa
        nombre_archivo=$(basename "$archivo_backup")
        
        # Expresión regular para extraer el nombre de usuario del nombre del archivo
        # Para backup individual: backup_alumno_20241210_143022.tar.bz2 -> usuario=alumno
        # Para backup de grupo: backup_alumno_grupo_20241210_143022.tar.bz2 -> usuario=alumno
        if [[ "$nombre_archivo" =~ ^backup_([^_]+)_ ]]; then
            usuario="${BASH_REMATCH[1]}"
        else
            echo "Formato de archivo de backup no reconocido: $nombre_archivo"
            continue
        fi

        echo "Usuario del backup: $usuario"

        # Verifica que el usuario exista en el sistema antes de restaurar
        if ! usuario_existe "$usuario"; then
            echo "ERROR: El usuario $usuario no existe en el sistema"
            echo "Presione Enter para continuar..."
            read
            continue
        fi

        # Obtiene el directorio home del usuario desde /etc/passwd
        home_destino=$(getent passwd "$usuario" | cut -d':' -f6)

        echo 
        echo "¿Restaurar backup de $usuario en $home_destino?"
        echo "¡ADVERTENCIA: se van a sobreescribir los archivos existentes!"
        echo -n "Confirmar (s/n): "
        read confirmacion 
        
        if [ "$confirmacion" != "s" ]; then
            echo "Restauracion cancelada"
            continue
        fi

        # Crea directorio temporal para extraer el backup
        temp_dir=$(mktemp -d)

        echo "Restaurando backup..."

        # Extrae el backup en el directorio temporal
        if tar -xjf "$archivo_backup" -C "$temp_dir" 2>/dev/null; then
            # Busca la estructura de directorios dentro del backup extraído
            if [ -d "$temp_dir/home/$usuario" ]; then
                dir_origen="$temp_dir/home/$usuario" 
            elif [ -d "$temp_dir/$usuario" ]; then
                dir_origen="$temp_dir/$usuario"
            else
                dir_origen="$temp_dir"
            fi

            # rsync sincroniza los archivos del backup con el directorio home del usuario
            # -a preserva permisos y atributos, -v modo verbose
            echo "Copiando archivos a $home_destino..."
            rsync -av "$dir_origen/" "$home_destino"/ 2>/dev/null

            # Asegura que el usuario sea dueño de todos los archivos restaurados
            chown -R "$usuario:$usuario" "$home_destino"

            echo "Restauración completada"

            # Limpia el directorio temporal
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

# =============================================
# INICIALIZACIÓN Y PUNTO DE ENTRADA PRINCIPAL
# =============================================

# Carga la configuración persistente al inicio
cargar_configuracion

# Verifica privilegios y crea directorios necesarios
check_user
crear_dir_backup

# Manejo de modos de ejecución
if [ "$1" = "automatico" ]; then
    # Modo automático desde cron - ejecución no interactiva
    {
        echo "================================================"
        echo "$(date): INICIANDO BACKUP AUTOMÁTICO DIARIO"
        echo "================================================"
        
        # Verifica que los archivos necesarios existan
        echo "Verificando archivos necesarios..."
        if [ ! -f "$backup_list" ]; then
            echo "ERROR: No existe el archivo de lista: $backup_list"
            exit 1
        fi
        
        if [ ! -s "$backup_list" ]; then
            echo "INFO: Lista de backups vacía, no hay nada que hacer"
            exit 0
        fi
        
        # Ejecuta el backup diario automático
        echo "Ejecutando backup_diario..."
        if backup_diario; then
            echo "Backup automático diario completado exitosamente"
        else
            echo "Backup automático diario falló con código: $?"
        fi
        
        echo "================================================"
        echo "$(date): FINALIZANDO BACKUP AUTOMÁTICO DIARIO"
        echo "================================================"
    } >> /var/log/backups.log 2>&1
    exit 0
fi

# =============================================
# BUCLE PRINCIPAL - MODO INTERACTIVO
# =============================================

# Bucle principal del modo interactivo con menú
while true; do
    menu_alpha
    read opcion

    case $opcion in
        1)
            # Crear backup manual
            crear_backup
            ;;
        2)
            #   Activar/desactivar backup  automático
            toggle_backup_automatico
            ;;
        3)
            # Restaurar backup existente
            restaurar_backup
            ;;
        4)
            # Gestionar lista  de backups autom áticos
            gestionar_backup_auto
            ;;
        5)
            # Configurar opciones de respaldo remoto
            configurar_respaldo_remoto
            ;;
        6)
            # Ejecutar backup automático de prueba
            echo "Ejecutando backup automático de prueba..."
            backup_diario
            ;;
        7)
            # Verificar dependencias del sistema
            echo "Ejecutando verificación de dependencias..."
            verificar_dependencias
            echo "Verificación completada. Revisa /var/log/backups.log"
            ;;
        0)
            # Salir del programa
            echo "Cerrando programa"
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