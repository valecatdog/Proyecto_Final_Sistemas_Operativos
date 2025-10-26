#! /bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
modo sin parametros
actualmente estoy trabajando en gestion de usuarios, crear usuarios, crear usuarios por consola

HACER:
-que ande la lista de usuarios
-qeu se pueda crear grupos
-que se pueda borrar grupos
-que se vea la lista de grupos
-que se puedan añadir y dacar usuarios de grupos

y ta eso es todo lo qeu queda. despues se le pueden agregar mas cosas para hacerlo mas robusto
se le podria agregar la opcion de ponerle contraseña a un gruó


ayuda no me da la cabeza para mas
'
#COMIENZO DEL ESPACIO PARA FUNCIONES

generar_usuario() {
    local nombre
    local apellido
    local user
    local primeraLetra
    #se hace por separado porque al ponerle local de una se pierde el valor de retorno ($?, si es 0, 1 etc)

    nombre="$1"
    apellido="$2"
    primeraLetra=$(echo "$nombre" | cut -c1)
    user="$primeraLetra$apellido"
    usuario="${nombre}:${apellido}:$user"
    #parece qeu no se usa, pero mas adelante si se usa
}

add_usuario(){
    #verifico la salida de la funcion, si es distinta a 0 entonces actua
    local usuario
    local nombre
    local apellido
    #datos del usuario (almacenados como nombre:apellido:usuario)
    nombre="$(echo "$1" | cut -d: -f1)"
    apellido="$(echo "$1" | cut -d: -f2)"
    usuario="$(echo "$1" | cut -d: -f3)"
    
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
        echo "Error: el usuario $usuario ($nombre $apellido) ya existe en el sistema"
        echo "$1" >> cre_usuarios.log 
    fi
} 

usuario_existe() {
        local usuario
        usuario="$(echo "$1" | cut -d: -f3)"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #habra que escapar el $
        getent passwd "$usuario" >/dev/null
        : 'verifica si existe el usuario en passwd, si existe te imprime su info. como no qeuremos eso, lo mandamos a 
        /dev/null'
}

del_usuario(){
    local nombre
        local apellido
        local usuario
        
        nombre=$(echo "$1" | cut -d: -f1)
        apellido=$(echo "$1" | cut -d: -f2)
        usuario=$(echo "$1" | cut -d: -f3)

    if usuario_existe "$1"
    then
        sudo userdel -r "$usuario"
        echo "Usuario $usuario ($nombre $apellido) eliminado correctamente del sistema"
    else
        echo "Error: el usuario $usuario ($nombre $apellido) no existe en el sistema"
    fi
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
}

archivo_procesar(){
    verificar_archivo "$1"
    
    listaUsuarios=()
    for ((i = 1 ; i < $(wc -w < "$archivo") ; i+=2))
    do
        nombre="$(cat "$archivo" | cut -d" " -f$i)"
        apellido="$(cat "$archivo" | cut -d" " -f$((i+1)))"
        generar_user "$nombre" "$apellido"
        listaUsuarios+=("$usuario")
        #lo añade al array de usuario
        # si sobra un nombre (queda fuera de los pares que se van formando), simplemente no se usa
    done

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
                    valido=true

                    for ((i=1 ; i <= cantOpciones ; i++))
                    do
                        opcion=$(echo "$opciones" | cut -d" " -f$i)
                        if [[ "$opcion" =~ ^[0-9]+$ ]] && ((opcion > -1 && opcion < ${#listaUsuarios[@]}))
                            #los [] se llaman "test". los dobles son avanzados y soportan regex (expresiones regulares)
                            #PONER PARA QUE ES =~
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
                        opcionesInvalidas=""

                    fi
                    
                fi

            ;;
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
}

ingreso_usuario(){
    valido=false
    until [ "$valido" = true ]
    do
        generar_usuario "$1" "$2"

        echo "Que desea hacer?"
        echo "1. Crear usuario"
        printf "2. Eliminar usuario del sistema\n"
        read -rp "Elija una opción: " opcion

        if (( "$opcion" == 1 )) 2>/dev/null; then
        #mando el error a /dev/null porque pode ingresar cosas no numericas y te tira error, pero funciona bien
            valido="true"
            add_usuario "$usuario"
        elif (( "$opcion" == 2 )) 2>/dev/null; then
            valido="true"
            del_usuario "$usuario"
        else
            printf "\n----------------------------\n\n"
            echo "Error: opcion invalida"
            printf "\n----------------------------\n"
        fi
    done
}

gestion_usuarios(){
    clear
    echo "==GESTION DE USUARIOS=="
    printf "\n\n"

    echo "Desea ingresar un usuario o un archivo para procesar?"
    printf "\n"
    echo "0. Volver a menu anterior" 
    echo "1. Ingresar un archivo para procesar"
    echo "2. Ingresar un usuario"
    #NO ANDA
    echo "3. Listar usuarios existentes"
    printf "\n"
    read -rp "Opcion: " opcionCase11

    case $opcionCase11 in
        0)
            menu_usuarios_grupos 
            return 0
        ;;

        1)
            clear
            echo "==PROCESAR UN ARCHIVO=="
            printf "\n"
            read -rp "Ingrese la ruta del archivo a procesar (no ingresar nada para cancelar): " archivo
            if [ -z "$archivo" ]; then
                return 1
            else
                archivo_procesar "$archivo"
                return 0
            fi
        ;;
        
        2)
            clear
            echo "==INGRESAR UN USUARIO=="
            printf "\n"
            while true; do
                read -rp "Ingrese el nombre y apellido del usuario (no ingresar nada para cancelar): " nombre apellido
                #AGREGAR 0 PARA CANCELAR EN LA OTRA FUNCION
                if [[ "$nombre" =~ ^[A-Za-z]+$  && "$apellido" =~ ^[A-Za-z]+$ ]]
                then
                    ingreso_usuario "$nombre" "$apellido"
                    return 0
                elif [ -z "$nombre" ] && [ -z "$apellido" ]
                then
                    return 1
                else
                    echo "ERROR: formato de nombres incorrecto"
                    return 1
                fi
            done
        ;;

        3)
            clear
            echo "==LISTADO DE USUARIOS=="
            echo "*este listado solo contiene usuarios estandar"
            printf "\n\n"

            getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 { print $3 ". " $1 }'
            : ' getent passwd es lo mismo que cat /etc/passwd
            -F: funciona como un cut -d: 
            $ 3 es el 3er campo (tiene los uid). verifica que sea  >= 1000 (ahi empiezan los usuarios normales)
            60000 es aproximadamente el numero donde terminan los usuarios normales 
            { print $ 1 } imprime el primer campo (el nombre de usuario)
            '

            read -n 1 -srp "------Presione cualquier tecla para continuar------"
            return 0
        ;;
        *)
            read -t2 -n1 -rsp "Error: opción incorrecta" 
            clear
            return 1
        ;;
    esac

}



gestion_grupos(){
    clear
    echo "==GESTION DE GRUPOS=="
    printf "\n\n"
    echo "Desea ingresar un grupo o un archivo para procesar?"
    printf "\n"

    echo "0. Volver a menu anterior" 
    echo "1. Ingresar un archivo para procesar"
    echo "2. Ingresar un grupo"
    #NO ANDA
    echo "3. Listar grupos"
    printf "\n"
    read -rp "Opcion: " opcionCase11

    case $opcionCase11 in
        0)
            menu_usuarios_grupos
        ;;
        1)
            clear
            echo "==PROCESAR UN ARCHIVO=="
            printf "\n"
            read -rp "Ingrese la ruta del archivo a procesar (no ingresar nada para cancelar): " archivo
            #AGREGAR 0 PARA CANCELAR EN LA OTRA FUNCION    
            #archivo_procesar "$archivo"

            return 0
        ;;
        
        2)
            clear
            echo "==INGRESAR UN GRUPO=="
            printf "\n"
            validoOpcion112=false
            while [ "$validoOpcion112" = false ]
            do
                read -rp "Ingrese el nombre del grupo (no ingresar nada para cancelar): " grupo
                crear_grupo "$grupo"
            done

            return 0
        ;;

        3)
            echo "==LISTA DE GRUPOS=="
            #reminder: grupos del 1000 en adelante
            return 0
        ;;

        *)
            read -t2 -n1 -rsp "Error: opción incorrecta" 
            clear
            return 1
        ;;
    esac
}

crear_grupo(){
    local grupo
    grupo="$1"

    if getent group "$grupo" >/dev/null; then
        echo "El grupo '$grupo' ya existe"
    else
        groupadd "$grupo"
        echo "Grupo '$grupo' creado correctamente"
    fi
}

eliminar_grupo(){
    local grupo
    grupo="$1"

    if getent group "$grupo" >/dev/null; then
        groupdel "$grupo"
        echo "Grupo '$grupo' eliminado correctamente"
    else
        echo "El grupo '$grupo' no existe"
    fi
}

menu_usuarios_grupos(){
    while true 
    do
        clear
        echo "==GESTION DE USUARIOS Y GRUPOS=="
        printf "\n\n"
        #0  NO ANDA
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver al menu anterior"
        echo "1. Crear o eliminar usuarios"
        echo "2. Crear o eliminar grupos"
        echo "3. Incorporar o remover usuarios de grupos"
        #evitamos palabras con enie a toda costa para prevenir errores
        read -rp "Opcion: " opcionCase1
        
        case $opcionCase1 in
            0)
                menu_principal
                break
            ;;
            1)
                #crear/eliminar users
                while ! gestion_usuarios
                do
                    gestion_usuarios
                done
                break
            ;;

            2)
            #crear/eliminar grupos
                while ! gestion_grupos
                do
                    gestion_grupos
                    
                done

            ;;

            3)
            #usuarios&grupos
                

            ;;

            *)
                read -t2 -n1 -rsp "Error: opción incorrecta"
            ;;
        esac

    done
}


menu_principal(){
    valido="false"
    while [ "$valido" = false ]
        do
            clear
            #0 NO ANDA
            echo "==ELIJA UN MODO== "
            printf "\n"
            echo "CTRL+C. Salir"
            echo "1. Gestion de usuarios y grupos"
            echo "2. Gestion de backups"
            read -rp "Opcion: " opcion
            printf "\n--------------------------------\n\n"
            #el echo no expande el \n, printf si

            case $opcion in
                1)
                    menu_usuarios_grupos
                ;;
                
                2)
                #MODO GESTION DE BACKUPS,  LO HACER ARU
                    valido="true"
                    echo "te extraño"
                ;;
                
                *)
                    read -t2 -n1 -rsp "Error: opción incorrecta" 
                    : 't (timeout): tiempo de espera; -n (num. of char.): permite escribir sol un caracter. es util porque si el usuario
                    toca una tecla puede terminar el tiempo de espera antes, y previene que lo que el usuario escriba
                    se quede guardado para el proximo read (o sea ue limpia la entrada y previene errores); -s (secret/
                    silent): no muestra lo que escribe el usuario; -r (raw): no interpreta; -p (prompt): muestra el texto
                    '
                ;;
        esac    

     done

}


#FIN DEL ESPACIO PARA FUNCIONES 
#TODO LO QUE DIGA VOLVER AL MENU PRINCIPAL O RETROCEDER NO ANDA

#COMIENZA LO QE TENGO UQE PEGAR

menu_principal







#TERMINA LO QUE TENGO QUE PEGAR