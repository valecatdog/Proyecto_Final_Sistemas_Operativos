#!/bin/bash
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

#CORREGIDO Y COMENTADO
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

#CORREGIDO Y COMENTADO
add_usuario(){

    #verifico la salida de la funcion, si es distinta a 0 (no se encontró en /etc/passwd asi que no existe) actua
    #le pasamos el primer parametro que se le paso a la funcion actual
    if ! usuario_existe "$1"
    then
        #creamos las variables y las hacemos locales (solo existen para esta funcion)
        local usuario
        local nombre
        local apellido
        local letraNombre
        local letraApellido
        local passwd

        # extraemos los datos del usuario (almacenados como nombre:apellido:usuario)
        nombre="$(echo "$1" | cut -d: -f1)"
        apellido="$(echo "$1" | cut -d: -f2)"
        usuario="$(echo "$1" | cut -d: -f3)"

        #generar contraseña
        letraNombre=$(echo "$nombre" | cut -c1 | tr '[:lower:]' '[:upper:]')
        #extraemos la primera letra del nombre (como antes) y si esta en minuscula la pasamos a mayuscula
        letraApellido=$(echo "$apellido" | cut -c1 | tr '[:upper:]' '[:lower:]')
        #extraemos la primera letra del apellido (como antes) y si esta en mayuscula la pasamos a minuscula
        passwd="$letraNombre${letraApellido}#123456"
        #la contraseña va a se la letraNombre+letraApellido+#123456 (como pide la consigna)

        #ingresar usuario
        sudo useradd -mc "$nombre $apellido" "$usuario"
        : 'aniadimos el usuario con useradd. -m crea el directorio del usuario si no existe y
        -c agrema un comentario (nombre apellido). aunque el script deberia ser ejecutado con sudo, en caso
        de olvido, lo agregamos de todas formas 
        '
        echo "$usuario":"$passwd" | sudo chpasswd 
        #chpasswd, que asigna contrasenias, espera recibir parametros por entrada estandar. por eso el pipe
        sudo chage -d 0 "$usuario"
        #chage -d establece a fecha del ultimo cambio de la contrasenia, y 0 hace qeu expire inmediatamente

        echo "Usuario $usuario creado correctamente. Contraseña: $passwd"
        #mensaje para informar que el usuario se creo exitosamente
        
    else
        read -n1 -t1 -rsp "Error: el usuario $usuario ($nombre $apellido) ya existe en el sistema"
        : 'informa que el usuario ya existe, no se puede crear
        -n1: acepta un caracter. sirve para que la proxima vez qeu se haga un read, lo que se escribe en este no
        "contamine" el otro (limpia el buffer). -t1: tiempo de espera de un segundo, -r: no interpreta lo que
        escribe el usuario. -s: no muestra lo que se escribe. -p: para mosrtar el mensaje. Como no nos interesa
        si el usuario escribe algo no especificamos una variable para que se guarde
        '
        echo "$1" >> cre_usuarios.log 
        #pasamos la informacion del usuario (prierm parametro de la funcion) al log 
    fi
} 

#CORREGIDO Y COMENTADO
usuario_existe() {
        local usuario
        usuario="$(echo "$1" | cut -d: -f3)"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #habra que escapar el $
        getent passwd "$usuario" >/dev/null
        : 'verifica si existe el usuario en passwd, si existe te imprime su info. como no qeuremos eso, lo redirigimos 
        a /dev/null'
}

#-----------------------------------HASTA ACA ESTA BIEN-----------------------------------


#CORREGIDO NO COMENTADO
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
        read -n1 -t1 -rsp "Usuario $usuario ($nombre $apellido) eliminado correctamente del sistema"
    else
         read -n1 -t1 -rsp "Error: el usuario $usuario ($nombre $apellido) no existe en el sistema"
    fi
}

#CORREGIDO NO COMENTADO
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
    until false
    do
        if [ -f "$archivo" ] && [ -r "$archivo" ] &&  grep -qE '^[[:alpha:]]+[[:space:]]+[[:alpha:]]+' "$archivo" 
        #velifica que "archivo" sea un archivo valido (existente, legible y que contenga 2 o mas palabras (nomb y apell))
        then
            read -n1 -t1 -rsp "Archivo valido"
            return 0
        elif [ -z "$archivo" ]
        then    
            return 1
        else
            echo "Error: archivo invalido o no encontrado"
            read -rp "Ingrese una ruta válida (no ingresar nada para cancelar): " archivo
            clear
        fi
    done
    #fin del until
}

#CORREGIDO NO COMENTADO, SE PUEDE MEJORAR EL DESPLIEGUE DE USUARIOS
archivo_procesar(){
    listaUsuarios=()
    archivo=$1
    #definimos una lista para almacenar usuarios

    if ! verificar_archivo "$archivo"; then
    #si el archivo que se le pasa no devuelve 0 (error) te lleva al menu (pasa cuando se ingresa un archivo vacio)
        gestion_usuarios
    else

            #explicar
            while read -r nombre apellido _
            do
                generar_usuario "$nombre" "$apellido"
                listaUsuarios+=("$usuario")
            done< <(awk 'NF >= 2 {print $1, $2}' "$archivo")

        valido=false
        while [ "$valido" = false ]
        do
            #CAPAZ QUE HABRIA UQE HACER ALGO PARA RETROCEDER? 0?
            clear
            echo "==PROCESAR UN ARCHIVO==" 
            printf "\n"
            echo "Que desea hacer?"
            echo "0. Volver al menu de gestion de usuarios"
            echo "1. Crear usuarios"
            echo "2. Eliminar usuarios del sistema"
            read -rp "Opcion: " opcion
            printf "\n--------------------------------\n\n"
            #el echo no expande el \n, printf si

            case $opcion in
                0)
                    gestion_usuarios
                    return 
                ;;
                1)
                    clear
                    echo "==PROCESAR UN ARCHIVO==" 
                    printf "\n"
                    echo "Elegido: 1. Crear usuarios"

                    echo "Con qué usuarios desea trabajar? (ingrese sus numeros separados por espacios):"
                    #despliega todos los usuarios
                    for((i = 0 ; i < ${#listaUsuarios[*]} ; i++))
                    do
                    #MEJORAR
                    #awk 'F: {print "${i}. " $3 "(" $1 $2 ")" }' "${#listaUsuarios["$i"]}"
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
                    clear
                    echo "==PROCESAR UN ARCHIVO==" 
                    printf "\n"
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

                ;;
            esac
        done

    fi
}

#CORREGIDO NO COMENTADO
ingreso_usuario(){
    valido=false
    until [ "$valido" = true ]
    do
        generar_usuario "$1" "$2"

        clear
        echo "==PROCESAR UN ARCHIVO==" 
        printf "\n"
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
            printf "\n"
            echo "Error: opcion invalida"

        fi
    done
}

#CORREGIDO NO COMENTADO
gestion_usuarios(){
    while true; do
        clear
        echo "==GESTION DE USUARIOS=="
        printf "\n\n"

        echo "Desea ingresar un usuario o un archivo para procesar?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Ingresar un archivo para procesar"
        echo "2. Ingresar un usuario"
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
                if [ -n "$archivo" ]; then
                    archivo_procesar "$archivo"
                fi
            ;;
            
            2)
                clear
                echo "==INGRESAR UN USUARIO=="
                printf "\n"
                    read -rp "Ingrese el nombre y apellido del usuario (no ingresar nada para cancelar): " nombre apellido
                    if [[ "$nombre" =~ ^[A-Za-z]+$  && "$apellido" =~ ^[A-Za-z]+$ ]]
                    then
                        ingreso_usuario "$nombre" "$apellido"
                    elif [ -z "$nombre" ] && [ -z "$apellido" ]
                    then
                        :
                        #una forma de decir no hacer nada
                    else
                        read -n1 -t1 -rsp "ERROR: formato de nombres incorrecto"
                    fi
                ;;  
            3)
                clear
                echo "==LISTADO DE USUARIOS=="
                echo "*este listado solo contiene usuarios estandar"
                printf "\n"

                getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 { print $3 ". " $1 }'
                : ' getent passwd es lo mismo que cat /etc/passwd
                -F: funciona como un cut -d: 
                $ 3 es el 3er campo (tiene los uid). verifica que sea  >= 1000 (ahi empiezan los usuarios normales)
                60000 es aproximadamente el numero donde terminan los usuarios normales 
                { print $ 1 } imprime el primer campo (el nombre de usuario)
                '
                printf "\n"
                read -n 1 -srp "------Presione cualquier tecla para continuar------"
            ;;
            *)
                read -t2 -n1 -rsp "ERROR: opción incorrecta" 
                clear
            ;;
        esac
    done

}

#NADA ANDA DE ACA------------------------------------------
#NO CORREGIDO NI COEMTNADO
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

#NO ANDA
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

#NO ANDA
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

#NO ANDA
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
        printf "\n"
        read -rp "Opcion: " opcionCase1
        
        case $opcionCase1 in
            0)
                menu_principal
                break
            ;;
            1)
                #crear/eliminar users
                gestion_usuarios
            ;;

            2)
                #crear/eliminar grupos
                gestion_grupos
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

#HASTA ACA NO ANDA-------------------------------------

#CORREGIDO NO COMENTADO
menu_principal(){
    valido="false"
    while [ "$valido" = false ]
        do
            clear
            echo "==ELIJA UN MODO== "
            printf "\n"
            echo "CTRL+C. Salir"
            echo "1. Gestion de usuarios y grupos"
            echo "2. Gestion de backups"
            printf "\n"
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