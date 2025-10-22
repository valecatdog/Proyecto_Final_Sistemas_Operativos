#! /bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
-para un usuario
'

generar_usuario() {
    local nombre
    local apellido
    local user
    local primeraLetra
    #se hace por separado porque al ponerle local de una se pierde el valor de retorno ($?, si es 0, 1 etc)

    nombre="$1"
    apellido="$2"
    primeraLetra=$(echo "$nombre" | cut -c1)
    user="$primeraLetra$apellido"
    usuario="${nombre}:${apellido}:$user"
    #parece qeu no se usa, pero mas adelante si se usa
}



if  (($# == 1))
then
    echo "lo pusiste mal amiga"

#LO QUE TENGO QUE COPIAR    

elif (($# == 2))
then
    valido=false
    until [ "$valido" = true ]
    do
        generar_usuario "$1" "$2"

        echo "Que desea hacer?"
        echo "1. Crear usuario"
        printf "2. Eliminar usuario del sistema\n"
        read -rp "Elija una opción: " opcion

        if (( "$opcion" == 1 )) 2>/dev/null; then
        #mando el error a /dev/null porque pode ingresar cosas no numericas y te tira error, pero funciona bien
            valido="true"
            add_usuario "$usuario"
        elif (( "$opcion" == 2 )) 2>/dev/null; then
            valido="true"
            del_usuario "$usuario"
        else
            printf "\n----------------------------\n\n"
            echo "Error: opcion invalida"
            printf "\n----------------------------\n"
        fi
    done



#TEMRINA LO QUE TEGO QE COPIAR  
fi