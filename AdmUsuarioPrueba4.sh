#!/bin/bash
#espacio 2 para probar casos individuales
#TRABAJANDO EN:
: '
el menu de gestion de grupos
NO PROBE NADA!!!
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
            addDel_grupo "add"
        ;;
        2)
            addDel_grupo "del"
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
    clear
    echo "==GESTION DE GRUPOS=="
    echo "Eliminar un grupo"
    printf "\n\n"
    #obtengo todos los grupos de usuarios y los guardo en una lista
    listaGrupos=$(getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
    #muestro la lista con el indice
    echo "Que grupos desea eliminar? (ingrese sus numeros separados por espacios):"
    i=0
    #es como un for each de java, desplegamos grupos
    for opcion in "${listaGrupos[@]}"
    do  
        echo "${i}. $opcion"
        i=$((i+1))
    done

    read -rp "opcion/es (no ingrese nada para retroceder): " opciones
    
    #Si no se ingreso nada (te devuelve al menu)
    if [ -z "$opciones" ]
    then   
        gestion_grupos
        return
    else
    #Si sí se ingresaron grupos
        opciones=$(echo "$opciones" | tr -s ' ')
        #si hay varios espacion en blanco seguidos los convertimos en uno para evitar errores
        for opcion in $opciones; do
            if (( opcion >= 0 && opcion < ${#listaGrupos[@]})); then
                sudo groupdel "$opcion"
                print -n1 -t1 -srp "Se ha eliminado el grupo $opcion con exito"
                opcionesInvalidas+=" $opcion"
            fi
        done

        if [ -n "$opcionesInvalidas" ]
        then
        #NO SE SI ESTO DE DEV NULL ESTA BIEN ASI
            read -n1 -t1 -rsp "Las opciones invalidas ingresadas fueron: $(sort "$opcionesInvalidas" | uniq 2>/dev/null)"
            opcionesInvalidas=""
        fi
        
    fi

    gestion_grupos
}

add_grupo(){
    while true
    do
        clear
        echo "==GESTION DE GRUPOS=="
        echo "Crear un grupo"
        printf "\n\n"

        read -rp "Nombre del grupo (no ingrese nada para rertoceder): " nombre

        if [ -z "$nombre" ]
        then
            gestion_grupos
            return
        else
            #los nombres pueden empezar con letras o guiones bajos, y el resto puede ser letras, nuemros o guiones -_
            if [[ "$nombre" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]]; then
                sudo groupadd "$nombre"
                print -n1 -t1 -srp "El grupo $nombre fue creado con exito"
            else
                print -n1 -t1 -srp "ERROR: nombre invalido. Use letras, numeros y guiones (sin empezar por los dos ultimos)"
            fi
        fi


    done

}

gestion_grupos