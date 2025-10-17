#! /bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
-hacer que te permita seleccionar varios usuarios para trabajar
'
listaUsuarios=()


read -rp "1er user: " user1
read -rp "2do user: " user2
read -rp "3er user: " user3
listaUsuarios+=("$user1")
listaUsuarios+=("$user2")
listaUsuarios+=("$user3")

 usuariosTrabajar=()

    valido=false
    while [ "$valido" = false ]
    do
        #CAPAZ QUE HABRIA UQE HACER ALGO PARA RETROCEDER? 0?
        echo "Que desea hacer?"
        echo "1. Crear usuarios"
        echo "2. Eliminar usuarios del sistema"
        read -rp "Opcion: " opcion
        printf "\n--------------------------------\n\n"
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
                        echo "${i}. $usuario ($nombre $apellido)"
                    done

                    #toma las opciones y las guarda de a una en el array

                    read -rp "opcion/es: " opciones
                    for ((i=1 ; i <= $(echo "$opciones" | wc -w) ; i++))
                    do
                        opcion=$(echo "$opciones" | cut -d" " -f$i)
                        usuario="${listaUsuarios[$opcion]}"
                        usuariosTrabajar+=("$usuario")
                    done

                    if [ "${#usuariosTrabajar[@]}" -eq 0 ]
                    then
                        echo "No ha ingresado ninnun usuario valido"
                    else
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
                    fi
                    
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





