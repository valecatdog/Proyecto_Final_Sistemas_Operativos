#!/bin/bash
#espacio 2 para probar casos individuales
#TRABAJANDO EN:
: '
-ver si esta andando bien la verificacion del archivo
'
verificar_archivo(){
    valido="false"
    #variable para el untill
    archivo="$1"
    #guardo en la variable archivo  el valor del primer parametro ingresado (su ruta)
    : 'le puse comillas porque el valor de la variable puede contener espacios (no deberia) o caracteres especiales (*$?etc). Lo preciso para poder 
    #trabajar con la variable aunque hagan eso que dije'
   
    #verifica que se haya pasado un archivo valido. En otro caso, te sigue preguntando hasta que se lo ingreses
    #ALGO PARA ROMPER EL BUCLE SI TE ARREPENTISTE!!!

    #empezando con el valor de la variable en falso, hace lo siguiente hasta que valido sea true
    until [ "$valido" = "true" ]
    do
        if [ -f "$archivo" ] && [ -r "$archivo" ] &&  grep -qE '^[[:alpha:]]+[[:space:]]+[[:alpha:]]+' "$archivo" 
        #velifica que "archivo" sea un archivo valido (existente, legible y que contenga 2 o mas palabras (nomb y apell))
        then
            valido=true
            read -n1 -t1 -rsp "Archivo valido"
        elif [ -z "$archivo" ]
        then    
            read -n1 -t1 -rsp "Saliendo..."  
            break
        else
            echo "Error: archivo invalido o no encontrado"
            read -rp "Ingrese una ruta válida (no ingresar nada para cancelar): " archivo
        fi
    done
    #fin del until
}

echo "Archivo: UsuariosBien1.txt"
verificar_archivo UsuariosBien1.txt

echo "Archivo: UsuariosBien2.txt"
verificar_archivo UsuariosBien2.txt

echo "Archivo: UsuariosBien3.txt"
verificar_archivo UsuariosBien3.txt

echo "Archivo: UsuariosMal1.txt"
verificar_archivo UsuariosMal1.txt

echo "Archivo: UsuariosMal2.txt"
verificar_archivo UsuariosMal2.txt
