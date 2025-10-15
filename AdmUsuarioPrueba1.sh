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
            if [ "$(wc -w < archivo.txt)" -lt 2 ]
            then
                echo "Error: archivo invalido. Los archivos tienen que tener por lo menos dos palabras (nombre y apellido)"
                read -pr "Ingrese una ruta válida: " archivo
                valido=true
                #detiene el until
            else
                echo "Archivo valido"
            fi
        else
            #si no es valido
            echo "Error: archivo invalido o no encontrado"
            read -pr "Ingrese una ruta válida: " archivo
        fi
    done
    echo "-------------------------------------"
    #fin del until



    listaUsuarios=()
    #creo un array para todos los usuarios con los que se va a estar trabajando

    #recorro todos los elementod del archivo con un for
    for ((i = 1 ; i < $(wc -w < "$archivo") ; i+=2))
    do
        nombreUsuario=$(generar_username "$(cat "$archivo" | cut -d" " -f$i)" "$(cat "$archivo" | cut -d" " -f$((i+1)))")
        listaUsuarios+=("$nombreUsuario")
        #lo añade al array de usuarios

        # si sobra un nombre (queda fuera de los pares que se van formando), simplemente no se usa
    done

##############################################ESTA PARTE ESTA CORRECTA############################################

    valido=false
    while [ "$valido" = false ]
    do
        #CAPAZ QUE HABRIA UQE HACER ALGO PARA RETROCEDER? 0?
        echo "Que desea hacer?"
        echo "1. Añadir usuarios al sistema"
        echo "2. Eliminar usuarios del sistema"
        echo "-------------------------------------"
        read -p "Opcion: " opcion
    
        case $opcion in
            1)
                valido=true
                echo "Elegido: 1. Añadir un usuario al sistema"

                if (( ${#listaUsuarios[*]} > 1 ))
                then
                    echo "Con cuál usuario desea trabajar?:"
                    echo "0. Retroceder"
                    for((i = 0 ; i < ${#listaUsuarios[*]} ; i++))
                    do
                        echo "$((i+1)). ${listaUsuarios[i]}"
                    done
                    opValida=false
                    while [ "$opValida" = false ]
                    do
                        read -p "Opcion: " opcion
                        if (( opcion > -1 && $opcion <= ${#listaUsuarios[@]}))
                        then
                            opValida=true
                            #NOMBRE DE LA FUNCION QUE HACE USUARIOS. TIENE QUE RECIBIR UN PARAMETRO: NOMBRE DE USUARIO
                        else
                        echo "Opcion inválida. Vuelva a intentarlo"
                        fi
                    done
                else
                    echo "si no me da error"
                    #MANDA DIRECTO EL USUARIO A LA FUNCION
                fi

            #esto para aca, no se repite ni nada

            ;;
            2) 
                valido=true
                echo "Elegido: 2. Eliminar uno de los usuarios"
                if (( ${#listaUsuarios[*]} > 1 ))
                then
                    echo "Con cuál usuario desea trabajar?:"
                    echo "0. Retroceder"
                    for((i = 0 ; i < ${#listaUsuarios[*]} ; i++))
                    do
                        echo "$((i+1)). ${listaUsuarios[i]}"
                    done
                    opValida=false
                    while [ "$opValida" = false ]
                    do
                        read -p "Opcion: " opcion
                        if (( opcion > -1 && $opcion <= ${#listaUsuarios[@]} ))
                        then
                            opValida=true
                            #NOMBRE DE LA FUNCION QUE HACE USUARIOS. TIENE QUE RECIBIR UN PARAMETRO: NOMBRE DE 
                            #PARA FUTURO SE PODRIAN METER VARIOS USUARIOS
                        else
                        echo "No se ingresó una opcion valida, vuelva a intentarlo: "
                        fi
                    done
                else
                    #MANDA DIRECTO EL USUARIO A LA FUNCION
                fi
            ;;
            *)
                echo "Asegurese de elegir un valor válido"
            ;;
        esac
    done




#esto es el final del if principal
fi