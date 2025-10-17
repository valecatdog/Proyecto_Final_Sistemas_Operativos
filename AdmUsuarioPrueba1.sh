#! /bin/bash
#ARCHIVO PARA PRUEBAS DEL SCRIPT COMPLETO

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

    for ((i = 1 ; i < $(wc -w < "$archivo") ; i+=2))
    do
        nombre="$(cat "$archivo" | cut -d" " -f$i)"
        apellido="$(cat "$archivo" | cut -d" " -f$((i+1)))"
        nombreUsuario="$(echo "$nombre" | cut -c1)$apellido"
        listaUsuarios+=("${nombreUsuario}:${nombre}:${apellido}")
        #lo añade al array de usuario
        # si sobra un nombre (queda fuera de los pares que se van formando), simplemente no se usa
    done

#############################################ESTA PARTE ESTA CORRECTA############################################
    #CORREGIR:
: '
-si ingresas una opcion incorrecta que no te saque
-se ve medio raro el coso, arreglar el menu
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
                        echo "${i}. ${listaUsuarios[i]}"
                    done

                    opValida=false
                    while [ "$opValida" = false ]
                    do
                        read -rp "Opcion: " opcion
                        if (( opcion > -1 && opcion <= ${#listaUsuarios[@]}))
                        then
                            opValida=true
                            #add_user "USERNAME!!!"
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
                printf "\n--------------------------------"

            ;;
        esac
    done




#esto es el final del if principal
fi