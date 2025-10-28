#!/bin/bash
#espacio 2 para probar casos individuales
#TRABAJANDO EN:
: '
el menu de gestion de grupos
'

gestion_grupos(){
    while true
    do
        clear
        echo "==GESTION DE GRUPOS=="
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Crear grupos"
        echo "2. Eliminar grupos"
        echo "3. Listar grupos existentes"
        printf "\n"
        read -rp "Opcion: " opcionCase12

        case "$opcionCase12" in
        1)

        ;;
        2)
            del_grupo
            return
        ;;
        3)
            clear
            echo "==LISTADO DE GRUPOS=="
            echo "*este listado solo contiene usuarios estandar"
            printf "\n"
            getent group | awk -F: '$3 >= 1000 && $3 <= 60000 { print $3 ". " $1 }'
            printf "\n"
            read -n 1 -srp "------Presione cualquier tecla para continuar------"
        ;;
        *)
            print -n1 -t1 -srp "ERROR: opcion incorrecta"
        ;;
        esac
    done
}

del_grupo(){
    listaGruposgetent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' 
    nombre=$(echo "$1" | cut -d: -f1)
    apellido=$(echo "$1" | cut -d: -f2)
    user=$(echo "$1" | cut -d: -f3)

    if usuario_existe "$1"
    then
        sudo userdel -r "$user"
        read -n1 -t2 -rsp "Usuario $user ($nombre $apellido) eliminado correctamente del sistema"
        ingreso_usuario "$nombre" "$apellido"
        return
    else
         read -n1 -t2 -rsp "ERROR: el usuario $user ($nombre $apellido) no existe en el sistema"
         ingreso_usuario "$nombre" "$apellido"
         return
    fi
}