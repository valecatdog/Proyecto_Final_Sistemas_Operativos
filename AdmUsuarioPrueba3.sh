#!/bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
agregar usuaris a grupos
opcion de ingreesar manualmente
ingresar con un archivo


'
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
        #hay 2 ifs en vez de uno para poder indicarle especificamente al usuario que error hay
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
                if ! sudo gpasswd -a "$1" "$2" 2>/dev/null; then
                    read -n1 -t1 -srp "Usuario agregado correctamente" 
                else
                    read -n1 -t2 -srp "ERROR: no se pudo agregar el usuario al grupo" 
                fi
                gestion_usuarios_grupos
                return
            ;;

            2)
                if sudo gpasswd -d "$1" "$2" 2>/dev/null; then
                    read -n1 -t1 -srp "Usuario eliminado correctamente" 
                else
                    read -n1 -t2 -srp "ERROR: no se pudo agregar el usuario al grupo" 
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
: '
admin_usergroup_archivo(){
}

archivo_grupo_verificar(){
}
'

usuario_existe_user(){
    local user
    user="$1"
    if getent passwd "$user" >/dev/null; then
        return 0
    else 
        return 1
    fi
}

grupo_existe(){
    local group
    group="$1"
    if getent group "$group" >/dev/null; then
        return 0
    else 
        return 1
    fi   
}

gestion_usuarios_grupos