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
                if [ -n "$opciones" ]
                then
                    echo "No ha ingresado ningun usuario valido"
                else
                #Si sí se ingresaron usuarios
                    cantOpciones=$(echo "$opciones" | wc -w) 

                    for ((i=1 ; i <= cantOpciones ; i++))
                    do
                        opcion=$(echo "$opciones" | cut -d" " -f$i)
                        if ((opcion > -1 && opcion < ${#listaUsuarios[@]}))
                        then
                            usuario="${listaUsuarios[$opcion]}"
                            add_usuario "$usuario"
                        else
                            opcionesInvalidas+=" $i"
                        fi
                    done

                if [ -z "$opcionesInvalidas" ]
                then
                    echo "Las opciones invalidas ingresadas fueron:$opcionesInvalidas"
                fi
                        
                    


    





: '
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
                    '

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





