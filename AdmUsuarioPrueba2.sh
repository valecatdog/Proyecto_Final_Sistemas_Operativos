#! /bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
-para un usuario
'

if  (($# == 1))
then
    echo "lo pusiste mal amiga"

#LO QUE TENGO QUE COPIAR    

elif (($# == 2))
then
    valido=false
    until [ "$valido" ]
    do
        usuario=$(generar_username "$1" "$2")

        echo "Que desea hacer?"
        echo "1. Crear usuario"
        printf "2. Eliminar usuario del sistema\n"
        read -rp "Elija una opción: " opcion

        if (( "$opcion" = 1 )); then
            valido=true
            add_usuario "$usuario"
        elif (( "$opcion" = 2 )); then
            valido=true
            del_usuario "$usuario"
        else
            echo "Error: opcion incorrecta"
            printf "\n----------------------------\n"
        fi
    done



#TEMRINA LO QUE TEGO QE COPIAR  
fi