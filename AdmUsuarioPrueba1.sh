#! /bin/bash
#ARCHIVO PARA PRUEBAS DEL SCRIPT COMPLETO

#ACTUALMENTE TRABAJANDO EN:
: '
-ver que t permita ingresar varios usuarios a la vez para crearlos
convertir el hacer el formato nombre:apellido:usuario una funcion (linea 133 aprox)
'

#EXPLICACIONES
: '
-los read tienen -r para que no se intrprete lo que se escriba (el shell )
'

#ESPACIO PARA FUNCIONES
generar_username() {
    local primeraLetra
    primeraLetra="$(echo "$1" | cut -c1)"
    #se hace por separado porque al ponerle local de una se pierde el valor de retorno ($?, si es 0, 1 etc)
    pero no se por que aca abajo nno y ahi arriba si
    local nombreUsuario=$primeraLetra$2
    echo "$nombreUsuario"
}

export LC_ALL=C.UTF-8
: '
le dice al shell que use UTF-8 como codificación para todo. lo agregamos poruqe funciones como tr [:upper:] [:lower:]
no manejan por si solos la misma cantidad de caracteres y eso genera un problema en la ejecucion
'

add_usuario(){

    #verifico la salida de la funcion, si es distinta a 0 entonces actua
    if ! usuario_existe "$1"
    then
        #creo las variables y las hago locales (solo existen para esta funcion)
        local usuario
        local nombre
        local apellido
        local letraNombre
        local letraApellido
        local passwd

        #datos del usuario (almacenados como nombre:apellido:usuario)
        nombre="$(echo "$1" | cut -d: -f1)"
        apellido="$(echo "$1" | cut -d: -f2)"
        usuario="$(echo "$1" | cut -d: -f3)"

        #generar contraseña
        letraNombre=$(echo "$nombre" | cut -c1 | tr '[:lower:]' '[:upper:]')
        letraApellido=$(echo "$apellido" | cut -c1 | tr '[:upper:]' '[:lower:]')
        passwd="$letraNombre${letraApellido}#123456"

        echo "!CONTRASEÑA: $passwd"
        #ingresar usuario
        sudo useradd -mc "$nombre $apellido" "$usuario"
        echo "$usuario":"$passwd" | sudo chpasswd 
        #chpasswd espera recibir parametros por entrada estandar, por eso el pipe
        sudo chage -d 0 "$usuario"
        #hace ruqe la contraseña expire inmediatamente
        echo "Usuario $usuario creado correctamente"
        
    else
        echo "Error: el usuario ya existe en el sistema"
        echo "$1" >> cre_usuarios.log 
    fi
} 

usuario_existe() {
        local usuario
        usuario="$(echo "$1" | cut -d: -f3)"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #habra que escapar el $
        grep -q "^${usuario}:" /etc/passwd
}

##########################################################################




#SI NO SE INGRESAN PARAMETROS######################################################################################
if (($# == 0))
then
echo "sin parametros"
#todavia no hay nada


#SI SE INGRESA UN PARAMETRO######################################################################################
elif (($# == 1))
then
    valido=false
    #variable para el untill
    archivo="$1"
    #guardo en la variable archivo  el valor del primer parametro ingresado (su ruta)
    : 'le puse comillas porque el valor de la variable puede contener espacios (no deberia) o caracteres especiales (*$?etc). Lo preciso para poder 
    #trabajar con la variable aunque hagan eso que dije'
   
    #verifica que se haya pasado un archivo valido. En otro caso, te sigue preguntando hasta que se lo ingreses
    #ALGO PARA ROMPER EL BUCLE SI TE ARREPENTISTE!!!

    #empezando con el valor de la variable en falso, hace lo siguiente hasta que valido sea true
    until [ $valido ]
    do
        if [ -f "$archivo" ]
        #velifica que "archivo" sea un archivo valido (existente)
        #PODRIA VERIFICAR SI LA ESTRUCTURA ES VALIDA TAMMBIEN!!!
        then
            #si es valido
            echo "Archivo encontrado."
    
            #le pongo comillas por las dudas de que me de mas de una palabra (no deberia). Es una buena practica.
            if [ "$(wc -w < "$archivo")" -lt 2 ]
            then
                echo "Error: archivo invalido. Los archivos tienen que tener por lo menos dos palabras (nombre y apellido)"
                read -rp "Ingrese una ruta válida: " archivo
                valido=true
                #detiene el until
            else
                echo "Archivo valido"
            fi
        else
            #si no es valido
            echo "Error: archivo invalido o no encontrado"
            read -rp "Ingrese una ruta válida: " archivo
        fi
    done
    echo "-------------------------------------"
    #fin del until

    listaUsuarios=()
#PUEDE SER UNA FUNCION
    for ((i = 1 ; i < $(wc -w < "$archivo") ; i+=2))
    do
        nombre="$(cat "$archivo" | cut -d" " -f$i)"
        apellido="$(cat "$archivo" | cut -d" " -f$((i+1)))"
        nombreUsuario="$(echo "$nombre" | cut -c1)$apellido"
        listaUsuarios+=("${nombre}:${apellido}:${nombreUsuario}")
        #lo añade al array de usuario
        # si sobra un nombre (queda fuera de los pares que se van formando), simplemente no se usa
    done

#############################################ESTA PARTE ESTA CORRECTA############################################
    #CORREGIR:
: '
-si ingresas una opcion incorrecta que no te saque
-se ve medio raro el coso, arreglar el menu
-hacer uqe se vea el nombre del usuairo y entre parantesis el nombre y el apellido
-que te cree el usuario obvi
'
    
    usuariosParaTrabajar=()

    valido=false
    while [ "$valido" = false ]
    do
        #CAPAZ QUE HABRIA UQE HACER ALGO PARA RETROCEDER? 0?
        echo "Que desea hacer?"
        echo "1. Crear usuarios"
        echo "2. Eliminar usuarios del sistema"
        read -rp "Opcion: " opcion
        printf "\n--------------------------------\n"
        #el echo no expande el \n, printf si

        case $opcion in
            1)
                valido="true"
                echo "Elegido: 1. Crear usuarios"

                if (( ${#listaUsuarios[*]} > 1 ))
                then
                    echo "Con qué usuarios desea trabajar? (ingrese sus numeros separados por espacios):"
                    echo "-1. Retroceder"
                    #el retroceder en realidad no te vuelve para atras, para todo
                    #despliega todos los usuarios
                    for((i = 0 ; i < ${#listaUsuarios[*]} ; i++))
                    do
                        nombre="$(echo "$1" | cut -d: -f1)"
                        apellido="$(echo "$1" | cut -d: -f2)"
                        usuario="$(echo "$1" | cut -d: -f3)"

                        nombre="$(echo "${listaUsuarios[$i]}" | cut -d: -f1)"
                        apellido="$(echo "${listaUsuarios[$i]}" | cut -d: -f2)"
                        usuario="$(echo "${listaUsuarios[$i]}" | cut -d: -f3)"
                        echo "${i}. ${nombre} ($nombre $apellido)}"
                    done

                    opValida=false
                    while [ "$opValida" = false ]
                    do
                        read -rp "Opcion: " opcion
                        if (( opcion > -1 && opcion <= ${#listaUsuarios[@]}))
                        then
                            opValida=true
                            add_usuario "${listaUsuarios[$opcion]}"
                        elif [ "$opcion" -eq -1 ]
                        then
                            opValida=true
                            #esto lo que hace es salir en realidad
                        else
                            echo "Opcion inválida. Vuelva a intentarlo"
                        fi
                    done

                    #UN USUARIO SOLO---------------------------------------------------------
                else
                    echo "si no me da error"
                    #MANDA DIRECTO EL USUARIO A LA FUNCION
                fi

            #esto para aca, no se repite ni nada

            ;;
            *)
            #*CASE TERMINADO
                echo "Asegurese de elegir un valor válido"
                printf "\n--------------------------------\n"

            ;;
        esac
    done




#esto es el final del if principal
fi