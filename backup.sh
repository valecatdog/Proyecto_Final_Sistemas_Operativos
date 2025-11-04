#!/bin/bash


# VARIABLES GLOBALES


# Archivo de configuración persistente donde se guardan los ajustes del usuario
CONFIG_FILE="/etc/backup-script/backup-config.conf"

# Configuración por defecto del sistema de backups
CRON_HORA="3"                           #--- hora programada para backup automatico *formato 24h*
CRON_MINUTO="10"                        #--- minuto programado para backup automático
RSYNC_DELAY_MINUTOS="5"                 #--- tiempo de espera antes de transferencia remota
REMOTE_BACKUP_ENABLED="true"            #--- habilitar/deshabilitar respaldo remoto
REMOTE_BACKUP_USER="respaldo_user"      #--- usurio para conexión SSH remota
REMOTE_BACKUP_HOST="192.168.0.93"       #--- dirección del servidor de backups remoto
REMOTE_BACKUP_DIR="/backups/usuarios"   #--- directorio destino en servidor remoto
SSH_KEY="/root/.ssh/backup_key"         #--- ruta de la clave SSH para autenticacion 


cargar_configuracion

# Variables de rutas y directorios del sistema
dir_backup="/var/users_backups"         #--- Directorio local donde se almacenan los backups
Delta=$(realpath "$0")                  # ---Ruta absoluta del script actual para referencias
backup_list="/etc/backup-script/auto-backup-list.conf"  # Lista de usuarios/grupos para backup automático



# Verifica que el script se ejecute con privilegios de root
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
        # ¡ESTO SOBRESCRIBE LOS VALORES POR DEFECTO CON LOS GUARDADOS!
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

#actualiza una variable de configuracion y guarda los cambios en archivo

actualizar_configuracion() {
    local variable="$1" # nombre de la variable a cambiar
    local valor="$2" # nuevo valor a asignar
    
    #magia negra eval nos permite asignar variables dinamicamente
    # *eval permite ejecutar codigo dinamico y lo usamos porque necesitamos cambiar variables que el nombre no lo conocemos de antemano*
    #  si $variable es "CRON_HORA" y $valor es "2", se convierte en:
    # CRON_HORA="2"
    eval "$variable=\"$valor\""
    
    # despues de cambiar la variable en memoria, la guardamos en disco
    #para que persista entre ejecuciones del script
    guardar_configuracion
    
    # loggeamos el cambio para tener auditoria
    echo "$(date): Configuración actualizada - $variable=$valor" >> /var/log/backups.log
}


# Convierte hora en formato 24h a formato AM/PM legible
formato_am_pm() {
    local hora_24h="$1"  # hora en formato 24h 0-23
    
    # caso especial: medianoche 0 horas
    if [ "$hora_24h" -eq 0 ]; then
        echo "12 AM"  # 00:00 se convierte en 12 AM
    
    # caso especial: medio dia (12 horas)  
    elif [ "$hora_24h" -eq 12 ]; then
        echo "12 PM"  # 12:00 se convierte en 12 PM
    
    # horas de la mañana 1-11
    elif [ "$hora_24h" -lt 12 ]; then
        echo "${hora_24h} AM"  # 1-11 AM
    
    # horas de la tarde/noche 13-23
    else
        # convertimos a formato 12h: 13-->1, 14-->2, ..., 23-->11
        local hora_pm=$((hora_24h - 12))
        echo "${hora_pm} PM"
    fi
}
 # obtiene la hora completa formateada para mostrarnos 
get_cron_hora_completa() {
    # primero convertimos la hora de 24h a AM/PM legible
    local hora_ampm=$(formato_am_pm "$CRON_HORA")
    
    # formateamos los minutos para que siempre tengan 2 digitos
    # printf "%02d" asegura que 5 se convierta en 05, 10 se mantiene 10
    # printf "%02d" es un comando que formatea números para que siempre tengan 2 dígitos, rellenando con ceros a la izquierda si es necesario. def oficial :D
    local minuto_formateado=$(printf "%02d" "$CRON_MINUTO")
    
    # combinamos todo en un formato legible: HH:MM (AM/PM)
    echo "${CRON_HORA}:${minuto_formateado} ($hora_ampm)"
}


# Verifica todas las dependencias necesarias para el funcionamiento del sistema
# Esta funcion es MUY importante para todo lo que sea debuggin y ver donde fallo asi evitar errores sileciosos como el lockfile que estuvo dando error como 14 horas y no entendia porque :)
verificar_dependencias() {
    local errores=0  # contador de errores, empezamos en 0 (todo bien)
    
    echo "Verificando dependencias del sistema..." >> /var/log/backups.log
    
    # SERVICIO ATD 
    # systemctl is-active --quiet verifica si el servicio está ejecutándose
    # ATD es necesario para programar transferencias remotas retardadas
    # 2>/dev/null silencia mensajes de error por si el servicio no existe
    if ! systemctl is-active --quiet atd 2>/dev/null; then
        echo "SERVICIO ATD: No está activo. Ejecuta: sudo systemctl enable atd && sudo systemctl start atd" >> /var/log/backups.log
        ((errores++))  # incrementamos el contador de errores
    else
        echo "SERVICIO ATD: Activo" >> /var/log/backups.log
    fi
    
    # CLAVE SSH 
    # Verifica que exista la clave SSH y tenga los permisos correctos (600)
    # Permisos 600 = solo el owner puede leer/escribir (crítico para seguridad)
    if [ ! -f "$SSH_KEY" ]; then
        echo "CLAVE SSH: No encontrada en $SSH_KEY" >> /var/log/backups.log
        ((errores++))
    elif [ "$(stat -c %a "$SSH_KEY" 2>/dev/null)" != "600" ]; then
        # stat -c %a obtiene los permisos en formato numérico (ej: 600, 644)
        echo "CLAVE SSH: Permisos incorrectos. Ajustando..." >> /var/log/backups.log
        chmod 600 "$SSH_KEY"  # corregimos automáticamente los permisos
        echo "CLAVE SSH: Permisos corregidos" >> /var/log/backups.log
    else
        echo "CLAVE SSH: Encontrada y con permisos correctos" >> /var/log/backups.log
    fi
    
    # CONECTIVIDAD REMOTA
    #  Verifica conectividad con el servidor remoto si está habilitado el respaldo remoto
    # solo verificamos si el usuario tiene habilitado el backup remoto
    if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
        # ssh con BatchMode=yes evita prompts interactivos modo no-interactivo
        # ConnectTimeout=5 limita el tiempo de espera a 5 segundos (no colgar)
        # "echo 'OK'" para probar que funciona
        # &>/dev/null redirige TODO el output a /dev/null 
        if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo 'OK'" &>/dev/null; then
            echo "CONECTIVIDAD: No se puede conectar a $REMOTE_BACKUP_HOST" >> /var/log/backups.log
            ((errores++))
        else
            echo "CONECTIVIDAD: Conexión remota funcionando" >> /var/log/backups.log
        fi
    fi
    
    #PERMISOS DEL SCRIPT 
    # Verifica que el script actual tenga permisos de ejecución
    # [ -x ] verifica si el archivo es ejecutable
    if [ ! -x "$Delta" ]; then
        echo "PERMISOS SCRIPT: No es ejecutable. Ajustando..." >> /var/log/backups.log
        chmod +x "$Delta"  # hacemos el script ejecutable automáticamente
        echo "PERMISOS SCRIPT: Corregidos" >> /var/log/backups.log
    else
        echo "PERMISOS SCRIPT: Ejecutable" >> /var/log/backups.log
    fi
    
    # RESUMEEEEN 
    # Resume el resultado de la verificación de dependencias
    if [ $errores -eq 0 ]; then
        echo "TODAS LAS DEPENDENCIAS: Verificadas correctamente" >> /var/log/backups.log
    else
        echo "SE ENCONTRARON $errores ERROR(ES) en las dependencias" >> /var/log/backups.log
    fi
    
    # retornamos el número de errores (0 = éxito, >0 = fallas)
    # rn bash 0 es "éxito" y cualquier otro número es "error" porsinosabian
    return $errores
}



# Programa una transferencia remota con 'at' para no bloquear el script principal
# El 'at' es como un cron para una sola ejecucion, pero mas flexible con tiempos relativos
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
    
    # mktemp crea un archivo temporal unico en /tmp
    # El XXXXXX se reemplaza con caracteres aleatorios para evitar colisiones
    local temp_script
    temp_script=$(mktemp /tmp/rsync_backup_XXXXXX.sh)

     # Creamos un script temporal que 'at' va a ejecutar
    
    # Usamos "here document" (<< EOF) para escribir multiples lineas
    # Las variables se expanden AHORA, cuando creamos el script
    # Las variables con \$ se expanden DESPUES, cuando se ejecute el script
    cat > "$temp_script" << SCRIPT_EOF
#!/bin/bash
# Script temporal para transferencia rsync
# Auto-eliminación al finalizar

# Estas variables se serean cuando el script se EJECUTE, no cuando se crea
LOG_FILE="/var/log/backups.log"
BACKUP_FILE="$archivo_backup"
REMOTE_USER="$REMOTE_BACKUP_USER"
REMOTE_HOST="$REMOTE_BACKUP_HOST"
REMOTE_DIR="$REMOTE_BACKUP_DIR"
SSH_KEY="$SSH_KEY"

# logeamos que empezamo  el \$(date) se evalua cuando corre el script, no ahora

echo "\$(date): [AT-TRANSFER] Iniciando transferencia programada de $nombre_archivo" >> "\$LOG_FILE"

#verificamos que el archivo todavia exista
# Esto es importante porque pueden pasar 5-15 minutos hasta que se ejecute este script
# Y en ese tiempo el archivo de backup podria haberse borrado o movido
# Verifica que el archivo todavía exista al momento de la ejecución
if [ ! -f "\$BACKUP_FILE" ]; then
    echo "\$(date): [AT-TRANSFER] ERROR: Archivo local desapareció: $nombre_archivo" >> "\$LOG_FILE"
    # limpiamos el scrit temporal antes de salr
    rm -f "$temp_script"
    exit 1
fi


# Probamos que podemos conectar al servidor remoto antes de intentar rsync
# Esto nos asegura que rsync se nos quede colgado esperando conexion
if /usr/bin/rsync -avz -e "ssh -i \$SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \\
    "\$BACKUP_FILE" \\
    "\$REMOTE_USER@\$REMOTE_HOST:\$REMOTE_DIR/" >> "\$LOG_FILE" 2>&1; then
    echo "\$(date): [AT-TRANSFER] TRANSFERENCIA EXITOSA: $nombre_archivo" >> "\$LOG_FILE"
else
    echo "\$(date): [AT-TRANSFER] ERROR en transferencia: $nombre_archivo" >> "\$LOG_FILE"
fi


#el script temporal se elimina a si mismo despues de ejecutarse
# Si no hicieramos esto, /tmp se llenaria de scripts viejos asquerosos
# Auto-limpieza: elimina el script temporal después de ejecutarse
rm -f "$temp_script"
SCRIPT_EOF
    
    # HACEMOS EL SCRIPT EJECUTABLE

# 'at necesita que el script tenga permisos de ejecucion
    # chmod +x agrega el permiso de ejecucion para el owner
    chmod +x "$temp_script"
    
    # at ejecuta comandos en un tiempo especifico
    # "now + X minutes" = ejecutar dentro de X minutos desde ahora
    local tiempo_at="now + $delay_minutos minutes"

    # Le pasamos el script a 'at' via stdin (con echo y pipe)
    # at lo guarda internamente y lo ejecutara en el tiempo programado
    if echo "$temp_script" | at "$tiempo_at" 2>/dev/null
    then
    # Si at acepto el trabajo, loggeamos exito
        echo "Transferencia remota programada: $nombre_archivo" >> /var/log/backups.log
        return 0
    else
    # Si at fallo, limpiarmos el script temporal y reportamos error    
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


#   Verifica si un usuario existe en el sistema
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

#    Obtiene la lista de usuarios pertenecientes a un grupo
obtener_usuarios_de_grupo() {
    local grupo="$1"
        # getent group obtiene la entrada del grupo, cut extrae el campo 4 (miembros)
    # tr convierte las comas en saltos de línea para procesar cada usuario por separado
    getent group "$grupo" | cut -d: -f4 | tr ',' '\n'
}


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


#muestra el menu de gestión de lista de backups automáticos
# es un menu, no hay mucho que explicar, ejem...
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


 # Crea backup de todos los usuarios pertenecientes a un grupo
crear_backup_grupo(){
    # Primero pedimos el nombre del grupo al usuario, con opción de cancelar
    # Esto es importante porque el usuario podría arrepentirse
    if ! leer_con_cancelar "Ingrese nombre del grupo" grupo; then
        return 1  # Si el usuario cancela, salimos de la función
    fi
    
    # Verificamos que el grupo realmente exista en el sistema
    # No podemos hacer backup de un grupo fantasma
    if grupo_existe "$grupo"; then
        # Generamos un timestamp único para esta ejecución
        # Esto evita que se sobreescriban backups si se ejecuta múltiples veces el mismo día
        fecha=$(date '+%Y%m%d_%H%M%S')
        
        echo "Creando backup del grupo: $grupo"
        echo "Usuarios en el grupo:"
        
        # Creamos un archivo temporal como contador
        # Esto lo necesitamos porque no podemos modificar variables dentro de un pipe tuberiah
        local temp_counter=$(mktemp)
        echo "0" > "$temp_counter"  # Inicializamos el contador en 0
        
        # metemos un invento y procesamos cada usuario del grupo individualmente
        # El < <(obtener_usuarios_de_grupo) se llama "process substitution"
        # basicamente convierte la salida del comando en un "archivo temporal virtual"
        while IFS= read -r usuario; do
            # Verificamos que el usuario no esté vacío y que exista
            # A veces los grupos tienen usuarios que ya no existen
            if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                # Obtenemos el directorio home del usuario desde /etc/passwd
                # cut -d: -f6 extrae el sexto campo (home) separado por :
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                
                # Verificamos que el directorio home exista
                # No tiene sentido hacer backup de un directorio que no existe
                if [ -d "$home_dir" ]; then
                    echo "  - Creando backup de: $usuario"
                    
                    # Generamos el nombre del archivo de backup
                    # Incluye usuario, grupo y timestamp para ser único
                    archivo_backup="${dir_backup}/backup_${usuario}_grupo_${fecha}.tar.bz2"
                    
                    # Aquí creamos el backup REAL usando tar
                    # -c = crear archivo, -j = comprimir con bzip2, -f = archivo output
                    # -C / = cambia directorio raíz a / para paths relativos
                    if tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null; then
                        echo "    Backup creado: $(basename "$archivo_backup")"
                        
                        # Registramos en el log que se creó este backup
                        echo "$(date): Backup manual de grupo $grupo - usuario $usuario - $archivo_backup" >> /var/log/backups.log
                        
                        # Incrementamos el contador de usuarios procesados
                        # Usamos un archivo temporal porque el pipe crea un subshell
                        local current_count=$(cat "$temp_counter")
                        echo $((current_count + 1)) > "$temp_counter"
                        
                        # Programamos la transferencia remota si está habilitada
                        # Esto se ejecuta en segundo plano gracias a 'at'
                        programar_transferencia_remota "$archivo_backup"
                    else
                        echo "    Error al crear backup de $usuario"
                    fi
                fi
            else
                # Si el usuario no existe, lo reportamos pero continuamos
                echo "  - Usuario $usuario no existe, omitiendo"
            fi
        done < <(obtener_usuarios_de_grupo "$grupo")  # esto alimenta el while con la lista de usuarios
        
    # Leemos el contador final para saber cuántos usuarios procesamos
        local usuarios_procesados=$(cat "$temp_counter")
        
         # Limpiamos el archivo temporal del contador
        rm -f "$temp_counter"
        
        #    Mostramos resumen final al usuario
        echo "Backup de grupo completado: $usuarios_procesados usuarios procesados"
        
    else
        # Si el grupo no existe, informamos al usuario
        echo "El grupo $grupo no existe."
        return 1
    fi
}

# Menu principal para creación de backups manuales
crear_backup(){
    while true; do
        echo "¿Qué tipo de backup desea crear?"
        echo "1. Backup de usuario individual"
        echo "2. Backup de grupo (backups individuales por usuario)"
        echo "0. Volver al menú principal"
        read -p "Seleccione opción: " tipo_backup

        case $tipo_backup in
            1)
                # aca pedimos el usuario con opcion de cancelar
                # por si el usuario se arrepiente a ultimo momento
                if ! leer_con_cancelar "Ingrese nombre de usuario" usuario; then
                    break  # salimos del case si cancela
                fi

                # verificamos que el usuario exista en el sistema
                # no podemos hacer backup de un usuario que no existe
                if usuario_existe "$usuario"; then
                    # getent obtiene la info del usuario desde la base de datos del sistema
                    # cut -d: -f6 extrae solo el directorio home (campo 6)
                    home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                    
                     #   generamos un timestamp unico para evitar sobreescribir backups
                    # el formato AAAAMMDD_HHMMSS asegura que cada backup sea unico
                    fecha=$(date '+%Y%m%d_%H%M%S')
                    archivo_backup="/var/users_backups/backup_${usuario}_${fecha}.tar.bz2"
                    
                    echo "Creando backup de $home_dir"
                    # tar con opciones: c=crear, j=comprimir bzip2, f=archivo output
                     #  -C / cambia el directorio raiz para paths relativos
                    # 2>/dev/null silencia warnings menores pero mantiene errores criticos
                    if tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null; then
                        echo "Backup creado: $archivo_backup"
                        # registramos en el log para auditoria
                        echo "$(date): Backup manual de $usuario - $archivo_backup" >> /var/log/backups.log
                          # programamos transferencia remota si esta habilitada
                          # esto se ejecuta en segundo plano gracias a 'at'
                        programar_transferencia_remota "$archivo_backup"
                    else
                        echo "Error al crear el backup"
                        #   ****aqui podriamos agregar mas detalles del error**
                    fi
                else 
                    echo "El usuario $usuario no existe."
                    # podria ser que el usuario este mal escrito o fue eliminado
                fi
                break  # salimos del while despues de procesar
                ;;
            2)
                # delegamos la creacion de backups de grupo a otra funcion
                crear_backup_grupo
                break
                ;;
            0)
                echo "Volviendo al menú principal..."
                return 1  # retornamos error para indicar que se cancelo
                ;;
            *)
                echo "Opción inválida"
                # el while continua mostrando el menu hasta opcion valida
                ;;
        esac
    done
}

# Ejecuta el backup automático diario según la lista configurada
backup_diario(){
    # generamos un timestamp unico para esta ejecucion
    # esto es clave porque multiple backups no deben sobreescribirse
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local usuarios_procesados=0
    local archivos_creados=()  # array para trackear que backups se crearon
    local exit_code=0  # codigo de salida general de la funcion

    # Loggeamos el inicio del proceso con el PID para debugging
    # el PID es util por si hay multiples instancias corriendo
    echo "$(date): [BACKUP-DIARIO] Iniciando backup automático - PID: $$" >> /var/log/backups.log
    echo "$(date): [BACKUP-DIARIO] Fecha: $fecha" >> /var/log/backups.log

    # verificamos configuracion critica antes de proceder
         # esto evita que el script falle medio camino
    if [ -z "$CRON_HORA" ] || [ -z "$CRON_MINUTO" ]; then
        echo "ERROR: Variables CRON_HORA o CRON_MINUTO no configuradas" >> /var/log/backups.log
        return 1  # salimos con error si no hay configuracion basica
    fi

      # verificamos que exista la lista de backups y tenga contenido
      # no tiene sentido proceder si no hay nada que respaldar
    if [ ! -f "$backup_list" ]; then
        echo "ERROR: Archivo de lista no encontrado: $backup_list" >> /var/log/backups.log
        return 1
    fi

    # Verificamos si la lista esta vacia (solo comentarios o lineas vacias).
    if [ ! -s "$backup_list" ]; then
        echo "INFO: Lista vacía, no hay backups para realizar" >> /var/log/backups.log
        return 0  # esto no es un error, solo no hay trabajo
    fi

    echo "INFO: Leyendo lista de backups: $backup_list" >> /var/log/backups.log

    # aqui viene el nucleo del proceso: leemos cada linea del archivo de configuracion
    # IFS= read -r preserva espacios y caracteres especiales en los nombres
    while IFS= read -r linea; do
        # saltamos lineas vacias o comentarios (las que empiezan con #)
        # [[ ]] es mas robusto que [ ] para expresiones regulares
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue
        
        echo "INFO: Procesando línea: $linea" >> /var/log/backups.log

        # verificamos si es un grupo (empieza con @) o usuario individual
        if [[ "$linea" =~ ^@ ]]; then
            # ES UN GRUPO - procesamos todos los usuarios del grupo
            grupo="${linea#@}"  # removemos el @ del nombre del grupo
            
            if grupo_existe "$grupo"; then
                echo "GRUPO: Procesando grupo: $grupo" >> /var/log/backups.log
                
                # aqui usamos process substitution para iterar sobre los usuarios del grupo
                # < <(comando) convierte la salida en un "archivo temporal"
                while IFS= read -r usuario; do
                    # verificamos que el usuario no este vacio y exista
                    if [ -n "$usuario" ] && usuario_existe "$usuario"; then
                        # obtenemos el directorio home desde /etc/passwd
                        home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                        
                        if [ -d "$home_dir" ]; then
                            # generamos nombre de archivo con prefijo "diario_" para diferenciar
                            archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                            echo "INFO: Creando backup de $usuario en $archivo_backup" >> /var/log/backups.log
                            
                        # creamos el backup comprimido
                        #  >> /var/log/backups.log 2>&1 redirige TODO el output al log
                            if tar -cjf "$archivo_backup" -C / "$home_dir" >> /var/log/backups.log 2>&1; then
                                echo "EXITO: Backup creado: $usuario" >> /var/log/backups.log
                                ((usuarios_procesados++))  # incrementamos contador
                                archivos_creados+=("$archivo_backup")  # agregamos al array
                                
                                    # programamos transferencia remota si esta habilitada
                                    # usamos el delay configurado para no saturar la red
                                if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
                                    programar_transferencia_remota "$archivo_backup" "$RSYNC_DELAY_MINUTOS"
                                fi
                            else
                                echo "ERROR: Error creando backup: $usuario" >> /var/log/backups.log
                                exit_code=1  # marcamos error pero continuamos con los demas
                            fi
                        else
                            echo "ERROR: El directorio home de $usuario no existe: $home_dir" >> /var/log/backups.log
                        fi
                    else
                        echo "ERROR: Usuario $usuario no existe, omitiendo" >> /var/log/backups.log
                    fi
                done < <(obtener_usuarios_de_grupo "$grupo")  # alimentamos el while con la lista de usuarios
            else
                echo "ERROR: Grupo no existe: $grupo" >> /var/log/backups.log
                exit_code=1  # marcamos error pero continuamos procesando
            fi
        else
            # eS UN USUARIO INDIVIDUAL
            usuario="$linea"
            if usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                    echo "INFO: Creando backup de $usuario en $archivo_backup" >> /var/log/backups.log
                    
                    # mismo proceso que para usuarios de grupos
                    if tar -cjf "$archivo_backup" -C / "$home_dir" >> /var/log/backups.log 2>&1; then
                        echo "EXITO: Backup creado: $usuario" >> /var/log/backups.log
                        ((usuarios_procesados++))
                        archivos_creados+=("$archivo_backup")
                        
                        # transferencia remota si esta activa
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
    done < "$backup_list"  # leemos del archivo de configuracion

    # resumen final del proceso
    echo "EXITO: Completado: $usuarios_procesados usuarios procesados" >> /var/log/backups.log
    
    # retornamos el codigo de salida (0=exito, 1=algun error)
    return $exit_code
}


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
                # toggle del estado de respaldo remoto
                # esto es como un interruptor on/off
                if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
                    actualizar_configuracion "REMOTE_BACKUP_ENABLED" "false"
                    echo "Respaldo remoto DESACTIVADO"
                    echo "los backups se crearan solo localmente"
                else
                    actualizar_configuracion "REMOTE_BACKUP_ENABLED" "true"
                    echo "Respaldo remoto ACTIVADO"
                    echo "los backups se transferiran al servidor remoto"
                fi
                ;;
            2)
                # probamos la conexion con el servidor remoto
                # Estó es importante para diagnosticar problemas de red.
                probar_conexion_remota
                ;;
            3)
                    # mostramos toda la configuracion actual
                    # Esto lo usamos para debugear, dios me salve
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
                echo "Puedes editar manualmente en: $CONFIG_FILE (como root)"
                ;;
            4)
                # configuramos el delay de transferencia
                # esto evita que todas las transferencias se ejecuten al mismo tiempo
                echo -n "Nuevo delay en minutos (actual: $RSYNC_DELAY_MINUTOS): "
                read nuevo_delay
                
                # validamos que sea un numero positivo
                # [[ =~ ^[0-9]+$ ]] es una regex que verifica solo digitos
                if [[ "$nuevo_delay" =~ ^[0-9]+$ ]] && [ "$nuevo_delay" -gt 0 ]; then
                    actualizar_configuracion "RSYNC_DELAY_MINUTOS" "$nuevo_delay"
                    echo "Delay de transferencia actualizado a $RSYNC_DELAY_MINUTOS minutos"
                    echo "los proximos backups se transferiran despues de $RSYNC_DELAY_MINUTOS minutos"
                else
                    echo "Error: Debe ingresar un número positivo mayor a 0"
                    echo "ejemplo: 5, 10, 15, etc."
                fi
                ;;
            5)
                # configuramos la hora del backup automatico
                # esto es cuando cron ejecutara el script diariamente
                echo "Configuración de hora del backup automático"
                echo "Hora actual: $(get_cron_hora_completa)"
                echo
                
                # configuracion de HORA (0-23)
                echo -n "Nueva hora (0-23, actual: $CRON_HORA): "
                read nueva_hora
                
                # validamos que la hora este en rango valido
                if [[ "$nueva_hora" =~ ^[0-9]+$ ]] && [ "$nueva_hora" -ge 0 ] && [ "$nueva_hora" -le 23 ]; then
                    actualizar_configuracion "CRON_HORA" "$nueva_hora"
                    echo "Hora actualizada a $nueva_hora"
                else
                    echo "Error: Hora debe ser entre 0 y 23"
                    echo "ejemplo: 0=media noche, 12=medio dia, 23=11 PM"
                    
                    # preguntamos si quiere continuar con la configuracion de minutos
                    echo -n "¿Continuar configurando los minutos? (s/n): "
                    read continuar
                    if [ "$continuar" != "s" ]; then
                        continue  # volvemos al menu principal
                    fi
                fi
                
                # configuracion de MINUTO (0-59)
                echo -n "Nuevo minuto (0-59, actual: $CRON_MINUTO): "
                read nuevo_minuto
                
                # validamos que los minutos esten en rango valido
                if [[ "$nuevo_minuto" =~ ^[0-9]+$ ]] && [ "$nuevo_minuto" -ge 0 ] && [ "$nuevo_minuto" -le 59 ]; then
                    actualizar_configuracion "CRON_MINUTO" "$nuevo_minuto"
                    echo "Minuto actualizado a $nuevo_minuto"
                else
                    echo "Error: Minuto debe ser entre 0 y 59"
                    echo "ejemplo: 0, 15, 30, 45 para cuartos de hora"
                fi
                
                # mostramos la nueva hora configurada
                echo "Hora de backup actualizada a: $(get_cron_hora_completa)"
                echo "$(date): Hora de backup cambiada a $(get_cron_hora_completa)" >> /var/log/backups.log
                
                # si el backup automatico esta activo, necesitamos actualizar cron
                # porque cron sigue usando la hora vieja
                if backup_automatico_activo; then
                    echo "Actualizando programación en cron..."
                    toggle_backup_automatico  # Desactivar primero
                    toggle_backup_automatico  # Reactivar con nueva hora
                    echo "Cron actualizado con la nueva hora"
                fi
                ;;
            0)
                # alimos del menu de configuracion
                return 0
                ;;
            *)
                #  manejo de opciones invalidas
                echo "Opción inválida"
                echo "por favor seleccione una opcion del 0 al 5"
                ;;
        esac
    
        echo
        echo "Presione Enter para continuar..."
        read
    done
}



# Activa o desactiva el backup automático en crontab
toggle_backup_automatico(){
        # primero verificamos si ya esta activo el backup automatico
        # buscamos nuestro script en la crontab del usuario actual
    if backup_automatico_activo; then
        # MODO DESACTIVAR- removemos nuestra entrada de crontab
        
        # esto es un poco magico: 
        # 1. crontab -l lista el crontab actual
        # 2. grep -v "$Delta" remueve la linea que contiene nuestro script
        # 3. el nuevo crontab (sin nuestra linea) se pasa a crontab -
        (crontab -l 2>/dev/null | grep -v "$Delta") | crontab -
        
        echo "Backup automático DESACTIVADO"
        echo "los backups ya no se ejecutaran automaticamente"
        echo "$(date): Backup automático desactivado" >> /var/log/backups.log
        
    else
        # MODO ACTIVAR - agregamos nuestra entrada a crontab
        
        #  antes de activar, verificamos que todas las dependencias esten okei
        # no tiene sentido activar algo que va a fallar
        echo "Verificando dependencias antes de activar backup automático..." >> /var/log/backups.log
        
        if ! verificar_dependencias; then
            echo "ERROR: No se puede activar backup automático debido a errores en dependencias"
            echo "Revisa /var/log/backups.log para más detalles"
            echo "necesitas resolver los problemas antes de activar el backup automatico"
            return 1  # salimos con error
        fi
        
        # verificamos si la lista de backups esta vacia
        # [ ! -f ] verifica que el archivo existe
        # grep -v '^#' excluye lineas comentadas, grep -v '^$' excluye lineas vacias
        # read verifica si queda algo para leer (si la lista tiene contenido)
        if [ ! -f "$backup_list" ] || ! grep -v '^#' "$backup_list" | grep -v '^$' | read; then
            # la lista esta vacia, mostramos advertencia pero permitimos continuar
            echo "ADVERTENCIA: La lista de backups automáticos está vacía!"
            echo "No se realizarán backups hasta que añada usuarios/grupos."
            echo "Puede gestionar la lista en la opción 4 del menú principal."
            echo "¿Está seguro que quiere activar igualmente? (s/n)"
            read confirmar
            if [ "$confirmar" != "s" ]; then
                echo "Activación cancelada por el usuario"
                return 1
            fi
            echo
        fi
        
        # construimos la entrada de cron con la hora configurada
        # formato: minuto hora * * * comando
        # * * * * son: dia-mes mes dia-semana (todos = diario)
        local entrada_cron="$CRON_MINUTO $CRON_HORA * * * $Delta automatico"
        
        # esto es el truco para agregar una linea a crontab sin borrar las existentes:
        # 1. crontab -l obtiene el crontab actual (si existe)
        # 2. agregamos nuestra nueva linea al final
        # 3. todo se pasa a crontab - que reemplaza el crontab completo
        (crontab -l 2>/dev/null; echo "$entrada_cron") | crontab -
        
        echo "Backup automático ACTIVADO"
        echo "Se ejecutará diariamente a las $(get_cron_hora_completa)"
        echo "Las transferencias remotas se programarán con at"
        echo "$(date): Backup automático activado - $entrada_cron" >> /var/log/backups.log
        
        # mostramos confirmacion de lo que se configuro
        # para que puedas ver si quedo bien programado, tambien puesto por temas de debug 
        echo
        echo "Entrada de cron actual:"
        crontab -l | grep "$Delta"
        echo
        echo "Puedes verificar con: crontab -l"
    fi
}

# Restaura un backup seleccionado por el usuario
restaurar_backup(){
    while true; do
        echo "Backups disponibles:"
        # listamos todos los archivos de backup en el directorio
        # ls -1 muestra un archivo por linea, mas facil de procesar
        # nl enumera las lineas con formato bonito para seleccion
        ls -1 "$dir_backup"/*.tar.bz2 2>/dev/null | nl -w 2 -s '. '

        # $? contiene el exit status del ultimo comando (ls)
        # si ls no encuentra archivos, retorna error (!= 0)
        if [ $? -ne 0 ]; then
            echo "No hay backups disponibles."
            echo "Presione Enter para continuar..."
            read
            return 1  # salimos de la funcion
        fi

        echo
        echo -n "Seleccione el numero del backup a restaurar (0 para volver): "
        read numero 

        # el usuario puede cancelar la operacion
        if [ "$numero" = "0" ]; then
            echo "Volviendo al menú principal..."
            return 1
        fi

        # extraemos el archivo correspondiente al numero seleccionado
        # sed -n "${numero}p" imprime solo la linea numero $numero
        archivo_backup=$(ls -1 "$dir_backup"/*.tar.bz2 | sed -n "${numero}p")

        # verificamos que el numero sea valido (que sed encontro algo)
        if [ -z "$archivo_backup" ]; then
            echo "Numero invalido"
            continue  # volvemos al inicio del while
        fi
        
        # extraemos solo el nombre del archivo sin la ruta
        # util para mostrar al usuario y para extraer el usuario
        nombre_archivo=$(basename "$archivo_backup")
        
        # aca esta lo feo, extraemos el usuario del nombre del archivo
        # usamos regex para capturar el patron del nombre
        # regex: ^backup_([^_]+)_ busca "backup_" captura todo hasta el siguiente _ 
        # para backup individual: backup_alumno_20241210_143022.tar.bz2 --> usuario=alumno
        # para backup de grupo: backup_alumno_grupo_20241210_143022.tar.bz2 ---> usuario=alumno
        if [[ "$nombre_archivo" =~ ^backup_([^_]+)_ ]]; then
            usuario="${BASH_REMATCH[1]}"  # BASH_REMATCH[1] contiene lo que capturo el primer ()
        else
            echo "Formato de archivo de backup no reconocido: $nombre_archivo"
            continue  # no podemos proceder sin saber el usuario
        fi

        echo "Usuario del backup: $usuario"

        # verificamos que el usuario exista en el sistema
        # no podemos restaurar a un usuario que no existe
        if ! usuario_existe "$usuario"; then
            echo "ERROR: El usuario $usuario no existe en el sistema"
            echo "No se puede restaurar el backup"
            echo "Presione Enter para continuar..."
            read
            continue
        fi

        # Obtenemos el directorio home del usuario desde /etc/passwd
        # cut -d':' -f6 extrae el sexto cmpo (home) separado por :
        home_destino=$(getent passwd "$usuario" | cut -d':' -f6)

        # ***warning la restauracion SOBREESCRIBE archivos existentes
        echo 
        echo "¿Restaurar backup de $usuario en $home_destino?"
        echo "¡ADVERTENCIA: se van a sobreescribir los archivos existentes!"
        echo -n "Confirmar (s/n): "
        read confirmacion 
        
        # confirmacion final del usuario -esto es irreversible
        if [ "$confirmacion" != "s" ]; then
            echo "Restauracion cancelada"
            continue
        fi

        # creamos directorio temporal para extraer el backup
        # mktemp -d crea un directorio temporal unico y seguro
        temp_dir=$(mktemp -d)

        echo "Restaurando backup..."

        # extraemos el backup en el directorio temporal
        # -x extraer, -j descomprimir bzip2, -f archivo
        if tar -xjf "$archivo_backup" -C "$temp_dir" 2>/dev/null; then
            # ahora buscamos donde se extrajeron los archivos
            # el contenido puede estar en diferentes estructuras:
            
            # estructura 1: temp_dir/home/usuario/
            if [ -d "$temp_dir/home/$usuario" ]; then
                dir_origen="$temp_dir/home/$usuario" 
            
            # estructura 2: temp_dir/usuario/
            elif [ -d "$temp_dir/$usuario" ]; then
                dir_origen="$temp_dir/$usuario"
            
            # estructura 3: directamente en temp_dir
            else
                dir_origen="$temp_dir"
            fi

            # usamos rsync para copiar los archivos al home del usuario
            # -a archive mode (preserva permisos, timestamps, etc)
            # -v verbose (pero lo redirigimos a /dev/null para no saturar)
            echo "Copiando archivos a $home_destino..."
            rsync -av "$dir_origen/" "$home_destino"/ 2>/dev/null

            # CRITIICO: aseguramos que el usuario sea dueño de todos los archivos
            # chown -R cambia owner recursivamente
            chown -R "$usuario:$usuario" "$home_destino"

            echo "Restauración completada exitosamente"
            echo "Backup de $usuario restaurado en $home_destino"

            # registramos en el log para auditoria
            echo "$(date): Restaurado backup $nombre_archivo para usuario $usuario" >> /var/log/backups.log

            # limpiamos el directorio temporal
            rm -rf "$temp_dir"
            
        else
            echo "ERROR: No se pudo extraer el backup - archivo corrupto o invalido"
            rm -rf "$temp_dir"  # limpiamos aunque haya fallado
        fi
        
        # pausa para que el usuario lea el resultado
        echo "Presione Enter para continuar..."
        read
        break  # salimos del while despues de una restauracion (exitosa o no)
    done
}



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
        echo "============================================="
    } >> /var/log/backups.log 2>&1
    exit 0
fi



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
            # Activar/desactivar backup automático
            toggle_backup_automatico
            ;;
        3)
            # Restaurar backup existente
            restaurar_backup
            ;;
        4)
            # Gestionar lista de backups automáticos
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