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
        
        0)
            menu_usuarios_grupos
            return
        ;;
        1)
            add_grupo
            return
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
            # awk filtra grupos por ID (1000-60000) y muestra numero y nombre
            getent group | awk -F: '$3 >= 1000 && $3 <= 60000 { print $3 ". " $1 }'
            printf "\n"
            read -n 1 -srp "------Presione cualquier tecla para continuar------"
        ;;
        *)
            read -n1 -t1 -srp "ERROR: opcion incorrecta"
        ;;
        esac
    done
}

del_grupo(){
    clear
    echo "==GESTION DE GRUPOS=="
    echo "Eliminar un grupo"
    printf "\n\n"
    # mapfile crea array con nombres de grupos del sistema
    mapfile -t listaGrupos < <(getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
    # awk -F: divide por campos usando : como separador
    # $3 >= 1000 && $3 < 60000 filtra por ID de grupo
    # {print $1} muestra solo el nombre del grupo
    
    echo "Que grupos desea eliminar? (ingrese sus numeros separados por espacios):"

    # bucle para mostrar lista numerada de grupos
    for ((i=0; i<${#listaGrupos[@]}; i++)); do
        echo "${i}. ${listaGrupos[$i]}"
    done
    
    printf "\n"
    set -f  # desactiva expansion de comodines
    read -rp "opcion/es (no ingrese nada para retroceder): " opciones
    
    # verifica si no se ingreso nada
    if [ -z "$opciones" ]
    then   
        gestion_grupos
        return
    else
        # limpia espacios multiples
        opciones=$(echo "$opciones" | tr -s ' ')
        opcionesInvalidas=""
        
        # procesa cada opcion ingresada
        for opcion in $opciones; do
            # verifica si opcion es numero valido
            if  [[ "$opcion" =~ ^[0-9]+$ ]] && (( "$opcion" >= 0 && "$opcion" < ${#listaGrupos[@]})) > /dev/null; then 
                sudo groupdel "${listaGrupos["$opcion"]}"
                read -n1 -t1 -srp "Se ha eliminado el grupo $opcion con exito"
            else
                opcionesInvalidas+=" $opcion"
            fi
        done
        
        # maneja opciones invalidas
        if [ -n "$opcionesInvalidas" ]
        then
            read -n1 -t1 -rsp "Las opciones invalidas ingresadas fueron: $(echo "$opcionesInvalidas" | sort | uniq 2>/dev/null)"
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

        # verifica si se presiono enter sin texto
        if [ -z "$nombre" ]
        then
            gestion_grupos
            return
        else
            # regex valida formato de nombre: letra/guion bajo al inicio, luego alfanumerico/guiones
            if [[ "$nombre" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]] && ! grupo_existe "$nombre"; then
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

gestion_usuarios_grupos(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS=="
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Agregar/borrar los usuarios indivudualmente"
        echo "2. Agregar/borrar los usuarios mediante un archivo"
        printf "\n"
        read -rp "Opcion: " opcionCase12                                                         
        case "$opcionCase12" in
        
        0)
            menu_usuarios_grupos
            return
        ;;
        1)
            admin_usergroup_manual_user
            return
        ;;
        2)
            admin_usergroup_archivo 
            return
        ;;
        *)
            read -n1 -t1 -srp "ERROR: opcion incorrecta"
        ;;
        esac
    done
}

admin_usergroup_manual_user(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        printf "\n\n"
        read -rp "Ingrese el usuario (enter para regresar): " usuario
        
        if [ -z "$usuario" ]
        then
            gestion_usuarios_grupos
            return
        elif [[ $usuario =~ ^[A-Za-z]+$ ]]
        then
            # verifica existencia de usuario
            if usuario_existe_user "$usuario"; then
                admin_usergroup_manual_grupo
                return
            else
                read -n1 -t1 -srp "ERROR: el usuario $usuario no existe"  
            fi
        else
            read -n1 -t1 -srp "ERROR: formato de nombre incorrecto"   
        fi
    done
}

admin_usergroup_manual_grupo(){
    while true
    do    
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        echo "*usuario: $usuario"
        printf "\n\n"
        read -rp "Ingrese el grupo (enter para regresar): " grupo
        
        if [ -z "$grupo" ]
        then
            admin_usergroup_manual_user
            return
        elif  [[ "$grupo" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]]
        then
            # verifica existencia del grupo
            if grupo_existe "$grupo"; then
                aniadir_quitar_usergrupo "$usuario" "$grupo"
                return
            else
                read -n1 -t1 -srp "ERROR: el grupo $grupo no existe"  
            fi
        else
            read -n1 -t1 -srp "ERROR: formato de nombre incorrecto"   
        fi
    done
}

aniadir_quitar_usergrupo(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        echo "*usuario: $1"
        echo "*grupo: $2"
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Agregarlo al grupo"
        echo "2. Quitarlo del grupo"
        printf "\n"
        read -rp "Opcion: " opcionaniadirQuitar

        case $opcionaniadirQuitar in
            0)
                admin_usergroup_manual_grupo
                return   
            ;;
        
            1)
                # verifica si usuario ya esta en el grupo
                if id -nG "$1" | grep -qw "$2"; then
                    read -n1 -t2 -srp "El usuario ya pertenece al grupo" 
                else
                    # agrega usuario al grupo con gpasswd
                    if sudo gpasswd -a "$1" "$2" &>/dev/null; then
                        read -n1 -t2 -srp "Usuario agregado correctamente" 
                    else
                        read -n1 -t2 -srp "ERROR: no se pudo agregar el usuario al grupo" 
                    fi
                fi
            ;;

            2)
                # elimina usuario del grupo con gpasswd
                if sudo gpasswd -d "$1" "$2" 2>/dev/null; then
                    read -n1 -t2 -srp "Usuario eliminado correctamente" 
                else
                    read -n1 -t2 -srp "ERROR: no se pudo eliminar el usuario del grupo" 
                fi 
                gestion_usuarios_grupos
                return
            ;;

            *)
               read -n1 -t1 -srp "ERROR: opcion incorrecta" 
            ;;
        esac
    done
}

admin_usergroup_archivo(){
    while true
    do
        
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS CON ARCHIVO=="
        printf "\n\n"
        read -rp "Ingrese la ruta del archivo (enter para regresar): " archivo
        if [ -z "$archivo" ]; then
            gestion_usuarios_grupos
            return
        else 
            # verifica que archivo exista y sea legible
            if [ -f "$archivo" ] && [ -r "$archivo" ]
                then
                listaUsuarios=()         
                # mapfile lee archivo y separa palabras por espacios
                mapfile -t palabras < <(tr -s '[:space:]' '\n' < "$archivo")

                if [ -n "${palabras[*]}" ]
                then
                    # procesa cada palabra del archivo
                    for palabra in "${palabras[@]}"; do
                        # verifica si palabra es usuario existente
                        if getent passwd "$palabra" > /dev/null; then
                            listaUsuarios+=("$palabra")
                        fi
                    done

                    read -t3 -n2 -srp "DEBUG: usuarios: ${listaUsuarios[*]}"

                    # verifica si se encontraron usuarios validos
                    if [ -n "${listaUsuarios[*]}" ]; then
                        admin_usergroup_archivo_grupo
                        return
                    else
                        read -t1 -n2 -srp "ERROR: el archivo no contiene ningun usuario valido"
                    fi
                else
                    read -t1 -n2 -srp "ERROR: el archivo esta vacio"
                fi

            else
                read -t1 -n2 -srp "ERROR: el archivo no existe o no se puede leer" 
            fi
        fi
    done
}

admin_usergroup_archivo_grupo(){
    while true
    do    
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS CON ARCHIVO=="
        echo "*archivo: $archivo"
        printf "\n\n"
        read -rp "Ingrese el grupo (enter para regresar): " grupo
        
        if [ -z "$grupo" ]
        then
            admin_usergroup_archivo
            return
        elif  [[ "$grupo" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]]
        then
            # verifica existencia del grupo
            if grupo_existe "$grupo"; then
                aniadir_quitar_usergrupo_archivo "$archivo" "$grupo"
                return
            else
                read -n1 -t1 -srp "ERROR: el grupo $grupo no existe"  
            fi
        else
            read -n1 -t1 -srp "ERROR: formato de nombre incorrecto"   
        fi
    done
}

aniadir_quitar_usergrupo_archivo(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS CON ARCHIVO=="
        echo "*archivo: $1"
        echo "*grupo: $2"
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Agregar usuarios al grupo"
        echo "2. Quitarlos del grupo"
        printf "\n"
        read -rp "Opcion: " opcionaniadirQuitar
    

        case $opcionaniadirQuitar in
            0)
                admin_usergroup_archivo_grupo
                return   
            ;;
        
            1)
                noAgregados=()
                # procesa cada usuario de la lista
                for u in "${listaUsuarios[@]}"
                do
                    # intenta agregar usuario al grupo
                    if ! sudo gpasswd -a "$u" "$2" &>/dev/null; then
                       noAgregados+=("$u")
                    fi
                done
                # maneja usuarios que no se pudieron agregar
                if [ -n "${noAgregados[*]}" ]
                then
                    read -t2 -n1 -srp "No se puedieron agregar los usuarios: ${noAgregados[*]}"
                else
                    read -t2 -n1 -srp "Usuarios agregados correctamente"
                fi
                gestion_usuarios_grupos
                return
            ;;

            2)
                noBorrados=()
                # procesa cada usuario de la lista
                for u in "${listaUsuarios[@]}"
                do
                    # intenta eliminar usuario del grupo
                    if ! sudo gpasswd -d "$u" "$2" &>/dev/null; then
                        noBorrados+=("$u")  
                    fi 
                done
                # maneja usuarios que no se pudieron eliminar
                if [ -n "${noBorrados[*]}" ]
                    then
                        read -t2 -n1 -srp "No se puedieron agregar los usuarios: ${noBorrados[*]}"
                    else
                        read -t2 -n1 -srp "Usuarios eliminados correctamente"
                fi
                gestion_usuarios_grupos
                return
            ;;

            *)
               read -n1 -t1 -srp "ERROR: opcion incorrecta" 
            ;;
        esac
    done
}

# funcion para verificar existencia de usuario
usuario_existe_user(){
    local user
    user="$1"
    if getent passwd "$user" >/dev/null; then
        return 0
    else 
        return 1
    fi
}

# funcion para verificar existencia de grupo
grupo_existe(){
    local group
    group="$1"
    if getent group "$group" >/dev/null; then
        return 0
    else 
        return 1
    fi   
}