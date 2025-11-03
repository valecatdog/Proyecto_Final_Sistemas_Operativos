#! /bin/bash

#en esta variable guardamos la direccion de donde se van a guardar los backups
dir_backup="/var/users_backups"
# Delta es el valor actual de este scrit, lo conseguimos con realpath
# tambien podriamos usar la direccion actual del script y ya, pero esto le da mas flexibilidad
Delta=$(realpath "$0")
lockfile="/var/lock/backup-script.lock"
# Archivo de configuracion para la lista de backups automaticos
backup_list="/etc/backup-script/auto-backup-list.conf"
REMOTE_BACKUP_USER="respaldo_user"
REMOTE_BACKUP_HOST="192.168.0.93"
REMOTE_BACKUP_DIR="/backups/usuarios"
SSH_KEY="/root/.ssh/backup_key"
REMOTE_BACKUP_ENABLED=true
CRON_HORA="3"
CRON_MINUTO="10"

#**investigar mas a detalle
cleanup() {
    echo "$(date): [CLEANUP] Ejecutando limpieza..." >> /var/log/backups.log
    # Eliminar lockfile si existe
    if [ -f "$lockfile" ]; then
        local current_pid=$$
        local lock_pid=$(cat "$lockfile" 2>/dev/null)
        
        # Solo eliminar si el lockfile es de este proceso o el proceso ya no existe
        if [ "$lock_pid" = "$current_pid" ] || [ -z "$lock_pid" ] || ! ps -p "$lock_pid" > /dev/null 2>&1; then
            rm -f "$lockfile"
            echo "$(date): [CLEANUP] Lockfile removido (PID: $lock_pid, Current: $current_pid)" >> /var/log/backups.log
        else
            echo "$(date): [CLEANUP] Lockfile NO removido - pertenece a proceso activo PID: $lock_pid" >> /var/log/backups.log
        fi
    fi
    # Eliminar directorio temporal si existe
    if [ -n  "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        echo "$(date): [CLEANUP] Directorio temporal removido: $temp_dir" >> /var/log/backups.log
    fi
}
#****** trap se encarga de ejecutar cleanup cuando el script termina (EXIT) o recibe señales (INT, TERM)
trap cleanup EXIT INT TERM

#**** funcion para verificar que el script se ejecute como root
check_user() {
    if [ "$(whoami)" != "root" ]; then
        echo "ERROR: Este script debe ejecutarse con sudo o como root"
        echo "Uso: sudo $0"
        exit 1
    fi
}

# funcion para adquirir el lock y evitar ejecuciones simultaneas
acquire_lock() {
    if [ -f "$lockfile" ]; then
        local lock_pid=$(cat "$lockfile" 2>/dev/null)
        if [ -n "$lock_pid" ] && ps -p "$lock_pid" > /dev/null 2>&1; then
            echo "ERROR: El script ya se está ejecutando en otro proceso (PID: $lock_pid)"
            echo "Lockfile encontrado: $lockfile"
            return 1
        else
            # Lockfile obsoleto, eliminarlo
            rm -f "$lockfile"
        fi
    fi
    
    # Crear nuevo lockfile
    echo $$ > "$lockfile"
    return 0
}

#**** funcion para liberar el lock
release_lock() {
    if [ -f "$lockfile" ]; then
        rm -f "$lockfile"
    fi
}

#***** funcion que ejecuta cualquier comando con lock para evitar races
execute_with_lock() {
    if ! acquire_lock; then
        return 1
    fi
    
    # Ejecutar la función pasada como parámetro
    "$@"
    local result=$?
    
    # Liberar lock después de la operación
    release_lock
    
    return $result
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

# Función para configurar respaldo remoto
configurar_respaldo_remoto() {
    while true; do
        clear
        echo "=== CONFIGURACIÓN DE RESPALDO REMOTO ==="
        echo "Estado actual: $REMOTE_BACKUP_ENABLED"
        echo
        echo "1. Activar/Desactivar respaldo remoto"
        echo "2. Probar conexión remota"
        echo "3. Ver configuración actual"
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
    sudo mkdir -p "$dir_backup"
    sudo chmod 700 "$dir_backup"
    echo "Directorio de backups creado: $dir_backup"
    fi

 #***** si no existe el archivo de log, lo creamo
    if [ ! -f "/var/log/backups.log" ]; then
        touch "/var/log/backups.log"
        chmod 644 "/var/log/backups.log"
    fi
    
    #***** crear directorio de configuracion si no existe
    if [ ! -d "/etc/backup-script" ]; then
        sudo mkdir -p "/etc/backup-script"
        sudo chmod 700 "/etc/backup-script"
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
    sudo crontab -l 2>/dev/null | grep -q "$Delta automatico"
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

crear_backup_grupo(){
    if ! leer_con_cancelar "Ingrese nombre del grupo" grupo; then
        return 1
    fi
    
    if grupo_existe "$grupo"; then
        fecha=$(date '+%Y%m%d_%H%M%S')
        
        echo "Creando backup del grupo: $grupo"
        echo "Usuarios en el grupo:"
        
        # Contador para usuarios procesados
        usuarios_procesados=0
        
        # Obtener usuarios del grupo y crear backup INDIVIDUAL para cada uno
        obtener_usuarios_de_grupo "$grupo" | while read usuario; do
            if usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    echo "  - Creando backup de: $usuario"
                    # CORREGIDO: Cambiamos el formato del nombre para que sea consistente
                    archivo_backup="${dir_backup}/backup_${usuario}_grupo_${fecha}.tar.bz2"
                    
                    # Crear backup individual del usuario
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null
                    then
                        echo "    Backup creado: $(basename "$archivo_backup")"
                        echo "$(date): Backup manual de grupo $grupo - usuario $usuario - $archivo_backup" >> /var/log/backups.log
                        ((usuarios_procesados++))
                        # Respaldo remoto automático
                        realizar_respaldo_remoto "$archivo_backup"
                    else
                        echo "    Error al crear backup de $usuario"
                    fi
                fi
            else
                echo "  - Usuario $usuario no existe, omitiendo"
            fi
        done
        
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
                        # Respaldo remoto automático
                        realizar_respaldo_remoto "$archivo_backup"
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

#***** MODIFICADA: funcion de backup diario que usa la lista configurada
backup_diario(){
    if ! acquire_lock; then
        echo "No se pudo adquirir lock, backup automático omitido" >> /var/log/backups.log
        return 1
    fi
    
    fecha=$(date '+%Y%m%d')
    usuarios_procesados=0

    echo "$(date): Iniciando backup automático" >> /var/log/backups.log

    # Verificar si el archivo de lista existe y tiene contenido
    if [ ! -f "$backup_list" ] || [ ! -s "$backup_list" ]; then
        echo "$(date): Lista de backups automáticos vacía, no se realizaron backups" >> /var/log/backups.log
        release_lock
        return 0
    fi

    # Leer la lista de backups automaticos (ignorar comentarios y lineas vacias)
    while IFS= read -r linea; do
        # Saltar lineas vacias o comentarios
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue
        
        if [[ "$linea" =~ ^@ ]]; then
            # Es un grupo - extraer nombre del grupo (sin el @)
            grupo="${linea#@}"
            if grupo_existe "$grupo"; then
                echo "$(date): Procesando grupo $grupo" >> /var/log/backups.log
                # Procesar cada usuario del grupo
                obtener_usuarios_de_grupo "$grupo" | while read usuario; do
                    if usuario_existe "$usuario"; then
                        home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                        if [ -d "$home_dir" ]; then
                            archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                            if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                                echo "$(date): Backup automático de $usuario (grupo $grupo) - $archivo_backup" >> /var/log/backups.log
                                ((usuarios_procesados++))
                                # Respaldo remoto automático
                                realizar_respaldo_remoto "$archivo_backup" &
                            fi
                        fi
                    fi
                done
            else
                echo "$(date): ERROR: Grupo $grupo no existe" >> /var/log/backups.log
            fi
        else
            # Es un usuario individual
            usuario="$linea"
            if usuario_existe "$usuario"; then
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                if [ -d "$home_dir" ]; then
                    archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                    if tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null; then
                        echo "$(date): Backup automático de $usuario - $archivo_backup" >> /var/log/backups.log
                        ((usuarios_procesados++))
                        # Respaldo remoto automático
                        realizar_respaldo_remoto "$archivo_backup" &
                    fi
                fi
            else
                echo "$(date): ERROR: Usuario $usuario no existe" >> /var/log/backups.log
            fi
        fi
    done < "$backup_list"

    echo "$(date): Backup automático completado - $usuarios_procesados usuarios procesados" >> /var/log/backups.log
    release_lock
    return 0
}

# funcion para activar/desactivar el backup automatico en crontab
toggle_backup_automatico(){
    if backup_automatico_activo; then
        # DESACTIVAR - eliminar de crontab
        #**** grep -v muestra todo EXCEPTO la linea que contiene nuestro script
        (sudo crontab -l 2>/dev/null | grep -v "$Delta automatico") | sudo crontab -
        echo "Backup automático DESACTIVADO"
    else
        # Mostrar advertencia si la lista está vacía
        if [ ! -f "$backup_list" ] || [ ! -s "$backup_list" ]; then
            echo "¡ADVERTENCIA: La lista de backups automáticos está vacía!"
            echo "No se realizarán backups hasta que añada usuarios/grupos."
            echo "Puede gestionar la lista en la opción 4 del menú principal."
            echo
        fi
        # ⭐⭐ MODIFICADO: Usar /bin/bash explícitamente para cron
        (sudo crontab -l 2>/dev/null; echo "$CRON_MINUTO $CRON_HORA * * * /bin/bash $Delta automatico") | sudo crontab -
        echo "Backup automático ACTIVADO"
        echo "Se ejecutará todos los días a las ${CRON_HORA}:${CRON_MINUTO}"
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
        if sudo tar -xjf "$archivo_backup" -C "$temp_dir" 2>/dev/null
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
            sudo chown -R "$usuario:$usuario" "$home_destino"

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

# punto de entrada del script - verifica usuario y crea directorios necesarios blablabla
check_user
crear_dir_backup

#***** VERIFICAR SI SE EJECUTA EN MODO AUTOMATICO (desde crontab) - VERSIÓN CON DEBUGGING
if [ "$1" = "automatico" ]; then
    {
        echo "================================================"
        echo "$(date): [CRON] INICIANDO BACKUP AUTOMÁTICO"
        echo "================================================"
        echo "Delta: $Delta"
        echo "Lockfile: $lockfile"
        echo "Backup list: $backup_list"
        echo "Remote backup enabled: $REMOTE_BACKUP_ENABLED"
        
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
        
        echo "Contenido de la lista de backups:"
        grep -v '^#' "$backup_list" | grep -v '^$' | while read line; do
            echo "  - $line"
        done
        
        # Limpieza agresiva de lockfiles obsoletos para cron
        echo "Verificando lockfile..."
        if [ -f "$lockfile" ]; then
            lock_pid=$(cat "$lockfile" 2>/dev/null)
            if [ -n "$lock_pid" ]; then
                if ! ps -p "$lock_pid" > /dev/null 2>&1; then
                    echo "Eliminando lockfile obsoleto (PID $lock_pid no existe)"
                    rm -f "$lockfile"
                else
                    echo "ERROR: Script ya en ejecución (PID $lock_pid), omitiendo backup"
                    exit 1
                fi
            else
                # Lockfile vacío o inválido
                rm -f "$lockfile"
                echo "Eliminando lockfile inválido"
            fi
        else
            echo "No hay lockfile existente"
        fi
        
        # Ejecutar backup diario
        echo "Ejecutando backup_diario..."
        if backup_diario; then
            echo "Backup automático completado exitosamente"
        else
            echo "Backup automático falló con código: $?"
        fi
        
        echo "================================================"
        echo "$(date): [CRON] FINALIZANDO BACKUP AUTOMÁTICO"
        echo "================================================"
        
        # Limpieza final
        cleanup
    } >> /var/log/backups.log 2>&1
    
    exit 0
fi

while true; do
    menu_alpha
    read opcion

    case $opcion in
        1)
        # crear backup con lock para evitar ejecuciones simultaneas again
            execute_with_lock crear_backup
            ;;
        2)
            # No necesita lock porque solo modifica crontab
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