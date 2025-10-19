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
user4="hola:noexisto:hNoexisto"

listaUsuarios+=("$user1")
listaUsuarios+=("$user2")
listaUsuarios+=("$user3")
listaUsuarios+=("$user4")

#FUNCIONES

del_usuario(){
    if usuario_existe "$1"
    then
        local nombre
        local apellido
        local usuario
        
        nombre=$(echo "$1" | cut -d: -f1)
        apellido=$(echo "$1" | cut -d: -f2)
        usuario=$(echo "$1" | cut -d: -f3)

        sudo userdel -r "$usuario"
        echo "Usuario $usuario ($nombre $apellido) eliminado correctamente"
        
    else
        echo "Error: el usuario $usuario ($nombre $apellido) no existe"
    fi
}

usuario_existe() {
        local usuario
        usuario="$(echo "$1" | cut -d: -f3)"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #habra que escapar el $
        grep -q "^${usuario}:" /etc/passwd
}
#FIN FUNCIONES################################33


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
#############################################ESTA PARTE ESTA CORRECTA############################################
            2)
                echo "Elegido: 2. Eliminar usuarios del sistema"

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
                if [ -z "$opciones" ]
                then
                    echo "No ha ingresado ningun usuario"
                else
                #Si sí se ingresaron usuarios
                    cantOpciones=$(echo "$opciones" | wc -w) 
                    valido=true

                    for ((i=1 ; i <= cantOpciones ; i++))
                    do
                        opcion=$(echo "$opciones" | cut -d" " -f$i)
                        if [[ "$opcion" =~ ^[0-9]+$ ]] && ((opcion > -1 && opcion < ${#listaUsuarios[@]}))
                        then
                            usuario="${listaUsuarios[$opcion]}"
                            del_usuario "$usuario"
                        else
                            opcionesInvalidas+=" $opcion"
                        fi
                    done

                    if [ -n "$opcionesInvalidas" ]
                    then
                        echo "Las opciones invalidas ingresadas fueron:$opcionesInvalidas"
                        opcionesInvalidas=""
                    fi
                    
                fi
            ;;
            *)
                echo "Asegurese de elegir un valor válido"
                printf "\n--------------------------------\n"

            ;;
        esac
    done





