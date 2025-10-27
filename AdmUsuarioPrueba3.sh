#!/bin/bash
#espacio 2 para probar casos individuales
#TRABAJANDO EN:
: '
-ver si esta andando bien la verificacion del archivo
'

generar_usuario() {
    local nombre
    local apellido
    local user
    local primeraLetra
    #se hace por separado porque al ponerle local de una se pierde el valor de retorno ($?, si es 0, 1 etc)

    nombre="$1"
    #la variable nombre toma el valor del primer parametro 
    apellido="$2"
    primeraLetra=$(echo "$nombre" | cut -c1)
    #no se puede hacer cut -c1 $nombre poruqe cut no trabaja con el valor de las variables, por eso se usa un pipe
    user="$primeraLetra$apellido"
    #creamos el user del usuario con la primera letra del nombre y el apellido
    usuario="${nombre}:${apellido}:$user"
    #usamos el formato nombre:apellido:user porque es lo mas comodo para trababarlo en el resto del script
}

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
            break
        fi
    done
    #fin del until
}

archivo_procesar(){

    if ! verificar_archivo "$1"; then
    #si el archivo que se le pasa no devuelve 0 te lleva al menu (se ingreso un archivo vacio)
        echo "Archivo mal"
    else
        listaUsuarios=()
        #si no, se crea esta lista
        for ((i = 1 ; i < $(wc -l < "$archivo") ; i++))
        #y por cada linea del archivo (el for va de 1 hasta la cantidad de lineas que tenga el archivo)
        do
            if [ "$(sed -n "${i}p" "$archivo" | wc -w)" -ge 2 ]
            : 'se verifica que tenga por lo menos dos palabras. sed -n no imprime nada a menos que se especifique 
            porque sino imprimiria todo el ccontenido y al final la linea "$ {i}p" imprime la linea i del
             archivo, se cuenta con wc -l (lines) y si es mayor o igual a 2 se trabaja con la linea. 
            '
            then
                nombre=$(sed -n "${i}p" "$archivo" | awk '{print $1}')
                #y si sí se toma la primera como nombre
                apellido=$(sed -n "${i}p" "$archivo" | awk '{print $2}')
                #y la segunda como apellido
                generar_usuario "$nombre" "$apellido"
                #se envia a la funcion que devuelve toda la data del usuario
                listaUsuarios+=("$usuario")
                echo "${listaUsuarios[@]}"
                #y se agrega a la lista de usuarios que contenia la funcion
            fi
        done
    fi
}

echo "Archivo: UsuariosBien1.txt"
verificar_archivo UsuariosBien1.txt

echo "-------------------------"

echo "Archivo: UsuariosBien2.txt"
verificar_archivo UsuariosBien2.txt

echo "-------------------------"

echo "Archivo: UsuariosBien3.txt"
verificar_archivo UsuariosBien3.txt

echo "-------------------------"

echo "Archivo: UsuariosMal1.txt"
verificar_archivo UsuariosMal1.txt

echo "-------------------------"

echo "Archivo: UsuariosMal2.txt"
verificar_archivo UsuariosMal2.txt
