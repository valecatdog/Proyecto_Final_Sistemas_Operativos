#! /bin/bash


#en esta variable guardamos la direccion de donde se van a guardar los backups
dir_backup="/var/users_backups"
# Delta es el valor actual de este scrit, lo conseguimos con realpath
# tambien podriamos usar la direccion actual del script y ya, pero esto le da mas flexibilidad
Delta=$(realpath "$0")

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
    echo -n "Seleccione opción: "
}

# bubbles burried in this jungle
# lo mismo que hicimos en admUsuario
usuario_existe() {
    local usuario="$1"  
    grep -q "^${usuario}:" /etc/passwd
}

crear_backup(){
    echo "ingrese nombre de usuario del usuario que quiera hacer backup."
    read usuario

    if usuario_existe "$usuario" 
    then

    #**analizar mas en profundidad
    #getent (get entry) te da las entradas de datos del sistema
    #segun deepseek lo deberiamos usar por el tema de backups entre maquinas (el getent), si no se deberia usar grep 
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
        tar -cjf "$archivo_backup" "$home_dir"
        
        echo "Backup creado: $archivo_backup"

    else 
    echo "el usuario no existe."
    fi
}

# el script que se encarga de hacer respaldos automaticamente y luego guardarlo en un log, todo silenciosamente
# se guardan separados de los respaldos manuales
# se guardan la hora de los backups (siempre van a ser la misma pero para mantener registro) y el nombre de lo usuarios que hagan backup
backup_diario(){
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
}

toggle_backup_automatico(){
    if backup_automatico_activo; then
        # DESACTIVAR - eliminar de crontab
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


restaurar_backup(){
    echo "Backups disponibles:"
    # -1 te lo da en lista, con un archivo por linea 
    # nl = number lines se encarga de enumerar las lineas, -w 2 te da un ancho de dos digitos para los numeros -s es el separador despues del num, que en este caso es un . 
    ls -1 "$dir_backup"/*.tar.bz2 2>/dev/null | nl -w 2 -s '. '

    # $? guarda la salida del utimo comando, osea el ls que acabamos de hacer, si no hay backups retorna 1 y termina la ejecuccion
    if [ $? -ne 0 ]
    then
    return 1
    fi

    echo
    echo -n "Seleccione el numero del backup a restaurar: "
    read numero 

    # con ls -1 volvemos a listar los archivos de dir_backup 
    # p = print no es una p de caracter
    # sed nos muestra todas las lineas con -n no muestra nada, solo el numero que eligio el usuario (el directorio entero )
    archivo_backup=$(ls -1 "$dir_backup"/*.tar.bz2 | sed -n "${numero}p")


    # si archivo backup esta vacio o es invalido entonces se termina la ejecucion
    if [ -z "$archivo_backup" ]
    then
    echo "Numero invalido"
    return 1
    fi
    
    # usamos basename solo para agarrar el nombre del backup que queremos EJ: backup_user.tar.bz2 envez de la direccion entera
    nombre_archivo=$(basename "$archivo_backup")
    usuario=$(echo "$nombre_archivo" | cut -d'_' -f2)

    echo "usuario del backup: $usuario"


    # usando la funcion de u_e determina que si dicho usuario no existe se termina la ejecucion 
    if ! usuario_existe "$usuario"
    then
    echo "ERROR: UNF; el usuario $usuario no existe en el sistema"
    return 1
    fi

    #home destino es el directorio de usuario de un usuario, lo agarramos haciendole un cut a la linea passwd del usuario en el campo 6 que es donde esta el dir de usuario
    home_destino=$(getent passwd "$usuario" | cut -d':' -f6)

    echo 
    echo "¿Restaurar backup de $usuario en $home_destino?"
    echo "¡ADVERTENCIA: se van a sobreescribir los archivos existentes!"
    echo -n "desea continuar (s/n):"
    read confirmacion 
    sleep 1

    if [ "$confirmacion" != "s" ] 
    then
    echo "Restauracion cancelada"
    return 0
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
        sudo cp -r "$dir_origen"/* "$home_destino"/ 2>/dev/null
        sudo cp -r "$dir_origen"/.* "$home_destino"/ 2>/dev/null 2>&1

        # reparamos los permisos con un change owner recursivo en todo el directorio
        sudo chown -R "$usuario:$usuario" "$home_destino"

        echo "Restauración completada"

        # Limpiamos temp_dir y borramos todo lo que tiene dentro
        rm -rf "$temp_dir"

         else
        echo "ERROR: No se pudo extraer el backup"
        rm -rf "$temp_dir"
    fi
}


crear_dir_backup

while true
do

menu_alpha

read opcion

   case $opcion in
        1)
            crear_backup
            ;;
        2)
            toggle_backup_automatico  
            ;;
            
        3)
            restaurar_backup  
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
