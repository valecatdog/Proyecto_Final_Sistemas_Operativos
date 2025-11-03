#! /bin/bash

#en esta variable guardamos la direccion de donde se van a guardar los backups
dir_backup="/var/users_backups"
# Delta es el valor actual de este scrit, lo conseguimos con realpath
# tambien podriamos usar la direccion actual del script y ya, pero esto le da mas flexibilidad
Delta=$(realpath "$0")
lockfile="/var/lock/backup-script.lock"

#**investigar mas a detalle
cleanup() {
    echo "Ejecutando limpieza..."
    # Eliminar lockfile si existe
    if [ -f "$lockfile" ]; then
        rm -f "$lockfile"
        echo "Lockfile removido"
    fi
    # Eliminar directorio temporal si existe
    if [ -n  "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        echo "Directorio temporal removido"
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

# el script que se encarga de hacer respaldos automaticamente y luego guardarlo en un log, todo silenciosamente
# se guardan separados de los respaldos manuales
# se guardan la hora de los backups (siempre van a ser la misma pero para mantener registro) y el nombre de lo usuarios que hagan backup
backup_diario(){


    #***** adquiere lock para evitar ejecuciones simultaneas de backups automaticos
    if ! acquire_lock; then
        echo "No se pudo adquirir lock, backup automático omitido" >> /var/log/backups.log
        return 1
    fi
    fecha=$(date '+%Y%m%d')

    # le hacemos un for para cada usuario que tenemos en home 
    for usuario in /home/*
    do
    # -d check directory para ver si existe, devuelve true si existe
        if [ -d "$usuario" ]
        then
        #basename lo usamos porque necesitamos porque tenemos que agarrar el nombre final de la ruta que esta en usuario (para conseguir el nombre)
        nombre_u=$(basename "$usuario")
        archivo_backup="${dir_backup}/diario_${nombre_u}_${fecha}.tar.bz2"

        #empaquetamos y comprimos igual pero silencioso esta vez 
        tar -cjf "$archivo_backup" "$usuario" 2>/dev/null

        #guardamos un .log de respaldos automaticos con hora (siempre van a ser las 4 am)
        echo "$(date): Respaldo automatico: $nombre_u" >> /var/log/backups.log
        fi
    done
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
        # aca le decimos a cron que ejecute este script todos los dias a las 4 am
        # -v invert match, se encarga de mostrar todo Exepto lo que cuencide
        (sudo crontab -l 2>/dev/null; echo "0 4 * * * $Delta automatico") | sudo crontab -
        echo "Backup automático ACTIVADO"
        echo "Se ejecutará todos los días a las 4:00 AM"
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