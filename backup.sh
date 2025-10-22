#! /bin/bash


#en esta variable guardamos la direccion de donde se van a guardar los backups
dir_backup="/var/users_backups"
# Delta es el valor actual de este scrit, lo conseguimos con realpath
# tambien podriamos usar la direccion actual del script y ya, pero esto le da mas flexibilidad
Delta=$(realpath "$0")

#funcion para crear el directorio dir_backup si no existe
crear_dir_backup(){
    #si no existe un directorio (dir_backup) entonces lo crea
    if [ ! -d "$dir_backup" ]
    then
    sudo mkdir -p "$dir_backup"
    sudo chmod 700 "$dir_backup"
    echo "Directorio de backups creado: $dir_backup"
    fi
}

# se encarga de verificar si el backup esta up and running :D, crontab -l te da una lista con las tareas Cron actuales (te devuelve un 1 (true) si es false )
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
    
    echo "3. Salir"
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
        archivo_backup="/var/users_backups/backup_${usuario}_${fecha}.tar.gz"
        
        # Creando el backup
        # tar empaqueta lo que esta en la var archivo_backup, crea un nuevo arch con -c, con j lo comprimimos con bzip2, y -f le decimos el nombre del arch 
        echo "Creando backup de $home_dir"
        tar -cjf "$archivo_backup" "$home_dir"
        
        echo "Backup creado: $archivo_backup"

    else 
    echo "el usuario no existe."
    fi
}

# el scritp que se encarga de hacer respaldos automaticamente y luego guardarlo en un log, todo silenciosamente
# se guardan separados de los respaldos manuales
# se guardan la hora de los backups (siempre van a ser la misma pero para mantener registro) y el nombre de lo usuarios que hagan backup
backup_diario(){
    fecha=$(date '+%Y%m%d')

    # le hacemos un for para cada usuario que tenemos en home 
    for usuario in /home/*
    do
        if [ -d "$usuario" ]
        then
        #basename lo usamos porque necesitamos porque tenemos que agarrar el nombre final de la ruta que esta en usuario (para conseguir el nombre)
        nombre_u=$(basename "$usuario")
        archivo_backup="${dir_backup}/diario_${nombre_u}_${fecha}.tar.bz2"

        #empaquetamos y comprimos igual pero silencioso esta vez 
        tar -cjf "$archivo_backup" "$home_dir" 2>/dev/null

        #guardamos un log de respaldos 
        echo "$(date): Respaldo automatico: "$nombre_u" >> /var/log/backups.log"
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
        (sudo crontab -l 2>/dev/null; echo "0 4 * * * $Delta automatico") | sudo crontab -
        echo "Backup automático ACTIVADO"
        echo "Se ejecutará todos los días a las 4:00 AM"
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
            activar_backup_automatico
            ;;
        3)
            echo "¡Hasta luego!"
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
