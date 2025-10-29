#!/bin/bash
#espacio 2 para probar casos individuales
#TRABAJANDO EN:
: '
el menu de gestion de grupos
NO PROBE NADA!!!
mañana lo arreglo 10 min y queda pronto para meter a la funcion de vuelta
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
            add_grupo
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
    clear
    echo "==GESTION DE GRUPOS=="
    echo "Eliminar un grupo"
    printf "\n\n"
    #obtengo todos los grupos de usuarios y los guardo en una lista
    mapfile -t listaGrupos < <(getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
    : 'tambien conocido como readarray, s un comando que lee lineas de texto y las guarda en un array. con awk
    lo qeu hacemos es filtrar la lista de gruops (getent group), haciendo qeu solo muestre el nombre de los grupos
    de usuario. -t le agrega saltos de linea al final a cada elemento
    '
    #muestro la lista con el indice
    echo "Que grupos desea eliminar? (ingrese sus numeros separados por espacios):"


    #es como un for each de java, desplegamos grupos
    for ((i=0; i<${#listaGrupos[@]}; i++)); do
        echo "${i}. ${listaGrupos[$i]}"
    done
    
    printf "\n"
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
                            #arreglar esto
            if  [[ "$opcion" =~ ^[0-9]+$ ]] && (( "$opcion" >= 0 && "$opcion" < ${#listaGrupos[@]})) > /dev/null; then 
                sudo groupdel "${listaGrupos["$opcion"]}"
                read -n1 -t1 -srp "Se ha eliminado el grupo $opcion con exito"
            else
                opcionesInvalidas+=" $opcion"
            fi
        done
        if [ -n "$opcionesInvalidas" ]
        then
            set -f
            # desactivo la expansion de comdines por ahora, proque si  no al mostrar opciones incorrectas los expande
            read -n1 -t1 -rsp "Las opciones invalidas ingresadas fueron: $(echo "$opcionesInvalidas" | sort | uniq 2>/dev/null)"
            opcionesInvalidas=""
            #activo expansion de comodines
            set +f
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
                read -n1 -t1 -srp "El grupo $nombre fue creado con exito"
                break
            else
                read -n1 -t1 -srp "ERROR: nombre invalido. Use letras, numeros y guiones (sin empezar por los dos ultimos)"
            fi
        fi
    done

    gestion_grupos
}

gestion_grupos