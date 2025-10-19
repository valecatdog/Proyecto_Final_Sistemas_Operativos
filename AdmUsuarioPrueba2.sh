#! /bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
-hacer que te permita seleccionar varios usuarios para trabajar
'

#esto en el script normal no se hace asi
listaUsuarios=()
user1="hola:chau:hChau"
user2="chau:hola:cHola"
user3="vale:correa:vCorrea"
listaUsuarios+=("$user1")
listaUsuarios+=("$user2")
listaUsuarios+=("$user3")


########################EMPIEZA LOQ EU TENGO QEU COPIAR##############
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
                echo "Elegido: 1. Crear usuarios"

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

                read -rp "opcion/es: " opciones
                
                #Si no se ingreso nada (te devuelve al menu)
                if [ "${#usuariosTrabajar[@]}" -eq 0 ]
                then
                    echo "No ha ingresado ningun usuario valido"
                elif [ "$opciones" -eq -1 ]
                #Si se ingresa -1 te devuelve al menu
                then
                    valido=true
                else
                #Si sí se ingresaron usuarios
                    : '
                    creo que tengo una mejor idea (no lo borro x las dudas)
                        toma las opciones y las guarda de a una en el array
                        for ((i=1 ; i <= $(echo "$opciones" | wc -w) ; i++))
                        do
                            opcion=$(echo "$opciones" | cut -d" " -f$i)
                            usuario="${listaUsuarios[$opcion]}"
                            usuariosTrabajar+=("$usuario")
                        done
                    '

                    for ((i=1 ; i <= $(echo "$opciones" | wc -w) ; i++))
                        do
                            opcion=$(echo "$opciones" | cut -d" " -f$i)
                            usuario="${listaUsuarios[$opcion]}"
                            add_usuario "$usuario"
                        done


    






                #ESTO CREO UQE NO SIRVE
                    valido=true
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
                    
                

            #esto para aca, no se repite ni nada

            ;;
            *)
            #*CASE TERMINADO
                echo "Asegurese de elegir un valor válido"
                printf "\n--------------------------------\n"

            ;;
        esac
    done





