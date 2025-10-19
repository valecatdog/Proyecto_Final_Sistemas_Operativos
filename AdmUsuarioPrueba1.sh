#! /bin/bash
#ARCHIVO PARA PRUEBAS DEL SCRIPT COMPLETO

#ACTUALMENTE TRABAJANDO EN:
: '
-ver que t permita ingresar varios usuarios a la vez para crearlos
convertir el hacer el formato nombre:apellido:usuario una funcion (linea 133 aprox)

-Podriamos hacer algo para cancelar el si se ingreso un archivo valido, pero no me parece necesario porque con
ctrl c ya podes salir

-cuando metes varios ususaris si pones varios espacios se tranca

-podiramos poner el nombre que sobro cuando metes un archivo
'

#EXPLICACIONES
: '
-los read tienen -r para que no se intrprete lo que se escriba (el shell )
'

#ESPACIO PARA FUNCIONES
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!HAY QUE CAMBIAR ESTA FUNCION, YA NO SIRVE AMS
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

        #ingresar usuario
        sudo useradd -mc "$nombre $apellido" "$usuario"
        echo "$usuario":"$passwd" | sudo chpasswd 
        #chpasswd espera recibir parametros por entrada estandar, por eso el pipe
        sudo chage -d 0 "$usuario"
        #hace ruqe la contraseña expire inmediatamente

        echo "Usuario $usuario creado correctamente. Contraseña: $passwd"
        
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

#TERMINA ESPACIO DE FUNCIONES#########################################################################




#SI NO SE INGRESAN PARAMETROS######################################################################################
if (($# == 0))
then
echo "sin parametros"
#todavia no hay nada


#SI SE INGRESA UN PARAMETRO######################################################################################
elif (($# == 1))
then
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
        if [ -f "$archivo" ] && [ -r "$archivo" ] && [ "$(wc -w < "$archivo")" -gt 2 ]
        #velifica que "archivo" sea un archivo valido (existente, legible y que contenga 2 o mas palabras (nomb y apell))
        then
            echo "Archivo valido"
            valido=true
        else
            echo "Error: archivo invalido o no encontrado"
            read -rp "Ingrese una ruta válida: " archivo
        fi
    done
    echo "----------------------------------"
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
#ARREGLAR
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
                if [ -z "$opciones" ]
                then
                    echo "No ha ingresado ningun usuario"
                else
                #Si sí se ingresaron usuarios
                    cantOpciones=$(echo "$opciones" | wc -w) 

                    for ((i=1 ; i <= cantOpciones ; i++))
                    do
                        opcion=$(echo "$opciones" | cut -d" " -f$i)
                        if [[ "$opcion" =~ ^[0-9]+$ ]] && ((opcion > -1 && opcion < ${#listaUsuarios[@]}))
                            #los [] se llaman "test". los dobles son avanzados y soportan regex (expresiones regulares)
                        then
                            usuario="${listaUsuarios[$opcion]}"
                            add_usuario "$usuario"
                        else
                            opcionesInvalidas+=" $opcion"
                        fi
                    done

                    if [ -n "$opcionesInvalidas" ]
                    then
                        echo "Las opciones invalidas ingresadas fueron:$opcionesInvalidas"
                    fi
                    
                    #UN USUARIO SOLO---------------------------------------------------------
                fi

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