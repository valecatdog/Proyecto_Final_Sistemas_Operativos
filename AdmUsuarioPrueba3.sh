#! /bin/bash

#empezando con el valor de la variable en falso, hace lo siguiente hasta que valido sea true

valido="false"
archivo="$1"

    until [ "$valido" ]
    do
        if [ -f "$archivo" ] || [ -r "$archivo" ] || [ "$(wc -w < "$archivo")" -lt 2 ]
        #velifica que "archivo" sea un archivo valido (existente, legible y que contenga 2 o mas palabras (nomb y apell))
        then
            echo "Archivo valido"
        else
            echo "Error: archivo invalido o no encontrado"
            read -rp "Ingrese una ruta válida: " archivo
        fi
    done
    echo "-------------------------------------"
    #fin del until