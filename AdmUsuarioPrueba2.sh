#!/bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
modo sin parametros
actualmente estoy trabajando en gestion de usuarios, crear usuarios, crear usuarios por consola

HACER:
-que no se puedan tocar usuarios ni grupos del sistema
-que si no hay usuarios para crear/borrar que no te deje entrar a la opcion
-los grupos que se borren no pueden ser de usuario
-lo de las opciones incorrectas ingresadas no anda en ningun lado 
-confirmar si se quiere realmente borrar o crear el usuairo/grupo
-longitud de los nombres
-se podrian hacer mas customizables los rupos (contraseñas, cambiar nombres)
-FALTA LO DE AÑADIR USUARIOS A GRUPOS
'
#COMIENZO DEL ESPACIO PARA FUNCIONES

#NO CORREGIDO NO COMENTADO
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
                    return
                else
                    gestion_usuarios
                    return
                fi
            ;;
            
            2)
                clear
                echo "==INGRESAR UN USUARIO=="
                printf "\n"
                    read -rp "Ingrese el nombre y apellido del usuario (no ingresar nada para cancelar): " nombre apellido
                    if [ -z "$nombre" ] && [ -z "$apellido" ]
                    then
                        gestion_usuarios
                        return
                    elif [ -n "$nombre" ] && [ -n "$apellido" ]
                    then
                        ingreso_usuario "$nombre" "$apellido"
                        return
                    else
                        read -n1 -t1 -rsp "ERROR: procure escribir el nombre y el apellido del usuario"
                        gestion_usuarios
                        return
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

#CORREGIDO Y COMENTADO
#recibe nombre y apellido
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
    usuario_completo="${nombre}:${apellido}:$user"
    #usamos el formato nombre:apellido:user porque es lo mas comodo para trababarlo en el resto del script
}

#CORREGIDO Y COMENTADO
#recibe usuario completo
usuario_existe() {
    local user
    user="$(echo "$1" | cut -d: -f3)"
    if getent passwd "$user" >/dev/null; then
        return 0
    else 
        return 1
    fi
}

#CORREGIDO Y COMENTADO
#recibe usuario completo
add_usuario(){
    local user
    local nombre
    local apellido

    nombre="$(echo "$1" | cut -d: -f1)"
    apellido="$(echo "$1" | cut -d: -f2)"
    user="$(echo "$1" | cut -d: -f3)"

    if ! usuario_existe "$1"; then
        #generar contraseña
        letraNombre=$(echo "$nombre" | cut -c1 | tr '[:lower:]' '[:upper:]')
        #extraemos la primera letra del nombre (como antes) y si esta en minuscula la pasamos a mayuscula
        letraApellido=$(echo "$apellido" | cut -c1 | tr '[:upper:]' '[:lower:]')
        #extraemos la primera letra del apellido (como antes) y si esta en mayuscula la pasamos a minuscula
        passwd="$letraNombre${letraApellido}#123456"
        #la contraseña va a se la letraNombre+letraApellido+#123456 (como pide la consigna)

        #ingresar usuario
        sudo useradd -mc "$nombre $apellido" "$user"
        : 'aniadimos el usuario con useradd. -m crea el directorio del usuario si no existe y
        -c agrema un comentario (nombre apellido). aunque el script deberia ser ejecutado con sudo, en caso
        de olvido, lo agregamos de todas formas 
        '
        echo "$user":"$passwd" | sudo chpasswd 
        #chpasswd, que asigna contrasenias, espera recibir parametros por entrada estandar. por eso el pipe
        sudo chage -d 0 "$user"
        #chage -d establece a fecha del ultimo cambio de la contrasenia, y 0 hace qeu expire inmediatamente

        read -n1 -t2 -rsp "Usuario $user creado correctamente. Contraseña: $passwd"
        printf "\n"
        return
    else
        read -n1 -t3 -rsp "Error: el usuario $user ($nombre $apellido) ya existe en el sistema"
        printf "\n"
        : 'informa que el usuario ya existe, no se puede crear
        -n1: acepta un caracter. sirve para que la proxima vez qeu se haga un read, lo que se escribe en este no
        "contamine" el otro (limpia el buffer). -t1: tiempo de espera de un segundo, -r: no interpreta lo que
        escribe el usuario. -s: no muestra lo que se escribe. -p: para mosrtar el mensaje. Como no nos interesa
        si el usuario escribe algo no especificamos una variable para que se guarde
        '
        echo "$1" >> cre_usuarios.log 
        return
    fi
}

#CORREGIDO NO COMENTADO
#recibe usuario completo
del_usuario(){
    local nombre
        local apellido
        local user
        
        nombre=$(echo "$1" | cut -d: -f1)
        apellido=$(echo "$1" | cut -d: -f2)
        user=$(echo "$1" | cut -d: -f3)

    if usuario_existe "$1"
    then
        sudo userdel -r "$user"
        read -n1 -t2 -rsp "Usuario $user ($nombre $apellido) eliminado correctamente del sistema"
        printf "\n"
        return
    else
         read -n1 -t2 -rsp "ERROR: el usuario $user ($nombre $apellido) no existe en el sistema"
         printf "\n"
         return
    fi
}

#PARA USUARIOS INDIVIDUALES----------------------------
#NO CORREGIDO NO COMENTADO
#recibe nombre y apellido
ingreso_usuario(){
    local nombre
    local apellido
    nombre="$1"
    apellido="$2"

    if [[ "$nombre" =~ ^[A-Za-z]+$  && "$apellido" =~ ^[A-Za-z]+$ ]]
    then
        until false 
        do
            generar_usuario "$nombre" "$apellido"
            clear
            echo "==INGRESAR UN USUARIO==" 
            printf "\n"
            echo "Que desea hacer?"
            echo "0. Volver al menu de gestion usuarios"
            echo "1. Crear usuario"
            echo "2. Eliminar usuario del sistema"
            printf "\n"
            read -rp "Elija una opción: " opcion

            if(( "$opcion" == 0 )) 2>/dev/null; then
                gestion_usuarios
                return
            elif(( "$opcion" == 1 )) 2>/dev/null; then
            #mando el error a /dev/null porque pode ingresar cosas no numericas y te tira error, pero funciona bien
                add_usuario "$usuario_completo" > /dev/null
                ingreso_usuario "$nombre" "$apellido"
                return
            elif (( "$opcion" == 2 )) 2>/dev/null; then
                del_usuario "$usuario_completo" > /dev/null
                ingreso_usuario "$nombre" "$apellido"
                return
            else
                printf "\n"
                read -n1 -t1 -srp "Error: opcion invalida"
                ingreso_usuario "$nombre" "$apellido"
                return
            fi
        done                          
    else
        read -n1 -t6 -rsp "ERROR: formato de nombres incorrecto"
        gestion_usuarios
        return
    fi  
}
#-------------------------------------------------------


#PARA ARCHIVOS-------------------------------------------
#CORREGIDO NO COMENTADO
verificar_archivo(){
    clear
    archivo="$1"
    #guardo en la variable archivo  el valor del primer parametro ingresado (su ruta)
    : 'le puse comillas porque el valor de la variable puede contener espacios (no deberia) o caracteres especiales (*$?etc). Lo preciso para poder 
    #trabajar con la variable aunque hagan eso que dije'
   
    #verifica que se haya pasado un archivo valido. En otro caso, te sigue preguntando hasta que se lo ingreses


    #empezando con el valor de la variable en falso, hace lo siguiente hasta que valido sea true
    until false
    do
        if [ -f "$archivo" ] && [ -r "$archivo" ] &&  grep -qE '^[[:alpha:]]+[[:space:]]+[[:alpha:]]+' "$archivo" 
        #velifica que "archivo" sea un archivo valido (existente, legible y que contenga 2 o mas palabras (nomb y apell))
        then
            return 0
        elif [ -z "$archivo" ]
        then    
            return 1
        else
            echo "==PROCESAR UN ARCHIVO=="
            printf "\n"
            echo "Error: archivo invalido o no encontrado"
            read -rp "Ingrese una ruta válida (no ingresar nada para cancelar): " archivo
            clear
        fi
    done
    #fin del until
}

#NO CORREGIDO NO COMENTADO, TIENE LA FUNCION archivo_procesar_addDel QUE NO SE SI ANDA
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
            listaUsuarios+=("$usuario_completo")
        done< <(awk 'NF >= 2 {print $1, $2}' "$archivo")

        while  true; do
            #CAPAZ QUE HABRIA UQE HACER ALGO PARA RETROCEDER? 0?
            clear
            echo "==PROCESAR UN ARCHIVO==" 
            echo "*archivo: $archivo"
            printf "\n"
            echo "Que desea hacer?"
            echo "0. Volver al menu de gestion de usuarios"
            echo "1. Crear usuarios"
            echo "2. Eliminar usuarios del sistema"
            read -rp "Opcion: " opcion
            #el echo no expande el \n, printf si

            case $opcion in
                0)
                    gestion_usuarios
                    return 
                ;;
                1)
                    archivo_procesar_addDel "add"
                    archivo_procesar "$1"
                    return
                ;;
                2)
                    archivo_procesar_addDel "del"
                    archivo_procesar "$1"
                    return
                ;;
                *)
                    read -n1 -t1 -srp "Asegurese de elegir un valor válido"

                ;;
            esac
        done

    fi
}

#LAS OPCIONES INCORRECTAS NO SE MUESRTAN
#NO PROBADO NO COMENTADO
archivo_procesar_addDel(){
    local usuariosTrabajar=()
    local ind
    ind=0
    clear
    echo "==PROCESAR UN ARCHIVO==" 
    printf "\n"
    if [ "$1" = add ]
        then
        echo "Elegido: 1. Crear usuarios"
    else
        echo "Elegido: 2. Eliminar usuarios del sistema"
    fi

    echo "Con qué usuarios desea trabajar? (ingrese sus numeros separados por espacios o nada para volver al menu anterior):"
    #despliega todos los usuarios
    usuariosTrabajar=()

    for ((i = 0; i < ${#listaUsuarios[@]}; i++)); do
        IFS=':' read -r nombre apellido user <<< "${listaUsuarios[i]}"

        if ! getent passwd "$user" > /dev/null && [ "$1" = add ]
        then
            echo "$ind. $user ($nombre $apellido)"
            usuariosTrabajar+=("${listaUsuarios["$i"]}")
            ind=$((ind+1))
        elif getent passwd "$user" > /dev/null && [ "$1" = del ]
        then
            echo "$ind. $user ($nombre $apellido)"
            usuariosTrabajar+=("${listaUsuarios["$i"]}")
            ind=$((ind+1))
        fi
    done

    read -rp "opcion/es (no ingrese nada para retroceder): " opciones
    
    #Si no se ingreso nada (te devuelve al menu)
    if [ -z "$opciones" ]
    then   
        archivo_procesar "$archivo"
        return
    else
    #Si sí se ingresaron usuarios
        valido=true

        opciones=$(echo "$opciones" | tr -s ' ')
        #si hay varios espacion en blanco seguidos los convertimos en uno para evitar errores
        for opcion in $opciones; do
            if [[ "$opcion" =~ ^[0-9]+$ ]] && (( opcion >= 0 && opcion < ${#usuariosTrabajar[@]} )); then
                if [ "$1" = add ]
                then
                    add_usuario "${usuariosTrabajar[$opcion]}"
                else
                    del_usuario "${usuariosTrabajar[$opcion]}"
                fi
            else
                opcionesInvalidas+=" $opcion"
            fi
        done

        if [ -n "$opcionesInvalidas" ]
        then
        #NO SE SI ESTO DE DEV NULL ESTA BIEN ASI
            read -n1 -t1 -rsp "Las opciones invalidas ingresadas fueron: $(sort "$opcionesInvalidas" | uniq 2>/dev/null)"
            opcionesInvalidas=""
        fi
        
    fi

    archivo_procesar "$archivo"
    return
}
#-----------------------------------------------------

#GRUPOS------------------
gestion_grupos(){
    while true
    do
        clear
        echo "==GESTION DE GRUPOS=="
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Crear grupos"
        echo "2. Eliminar grupos"
        echo "3. Listar grupos existentes"
        printf "\n"
        read -rp "Opcion: " opcionCase12

        case "$opcionCase12" in
        1)
            add_grupo
        ;;
        2)
            del_grupo 
            return
        ;;
        3)
            clear
            echo "==LISTADO DE GRUPOS=="
            echo "*este listado solo contiene usuarios estandar"
            printf "\n"
            getent group | awk -F: '$3 >= 1000 && $3 <= 60000 { print $3 ". " $1 }'
            printf "\n"
            read -n 1 -srp "------Presione cualquier tecla para continuar------"
        ;;
        *)
            read -n1 -t1 -srp "ERROR: opcion incorrecta"
        ;;
        esac
    done
}

del_grupo(){
    clear
    echo "==GESTION DE GRUPOS=="
    echo "Eliminar un grupo"
    printf "\n\n"
    #obtengo todos los grupos de usuarios y los guardo en una lista
    mapfile -t listaGrupos < <(getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
    : 'tambien conocido como readarray, s un comando que lee lineas de texto y las guarda en un array. con awk
    lo qeu hacemos es filtrar la lista de gruops (getent group), haciendo qeu solo muestre el nombre de los grupos
    de usuario. -t le agrega saltos de linea al final a cada elemento
    '
    #muestro la lista con el indice
    echo "Que grupos desea eliminar? (ingrese sus numeros separados por espacios):"


    #es como un for each de java, desplegamos grupos
    for ((i=0; i<${#listaGrupos[@]}; i++)); do
        echo "${i}. ${listaGrupos[$i]}"
    done
    
    printf "\n"
    set -f
    read -rp "opcion/es (no ingrese nada para retroceder): " opciones
    
    #Si no se ingreso nada (te devuelve al menu)
    if [ -z "$opciones" ]
    then   
        gestion_grupos
        return
    else
    #Si sí se ingresaron grupos
        opciones=$(echo "$opciones" | tr -s ' ')
        #si hay varios espacion en blanco seguidos los convertimos en uno para evitar errores
        for opcion in $opciones; do
                            #arreglar esto
            if  [[ "$opcion" =~ ^[0-9]+$ ]] && (( "$opcion" >= 0 && "$opcion" < ${#listaGrupos[@]})) > /dev/null; then 
                sudo groupdel "${listaGrupos["$opcion"]}"
                read -n1 -t1 -srp "Se ha eliminado el grupo $opcion con exito"
            else
                opcionesInvalidas+=" $opcion"
            fi
        done
        if [ -n "$opcionesInvalidas" ]
        then
            # desactivo la expansion de comdines por ahora, proque si  no al mostrar opciones incorrectas los expande
            read -n1 -t1 -rsp "Las opciones invalidas ingresadas fueron: $(echo "$opcionesInvalidas" | sort | uniq 2>/dev/null)"
            opcionesInvalidas=""
            #activo expansion de comodines
        fi
        
    fi
    set +f
    gestion_grupos
}

add_grupo(){
    while true
    do
        clear
        echo "==GESTION DE GRUPOS=="
        echo "Crear un grupo"
        printf "\n\n"

        read -rp "Nombre del grupo (no ingrese nada para rertoceder): " nombre

        if [ -z "$nombre" ]
        then
            gestion_grupos
            return
        else
            #los nombres pueden empezar con letras o guiones bajos, y el resto puede ser letras, nuemros o guiones -_
            if [[ "$nombre" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]]; then
                sudo groupadd "$nombre"
                read -n1 -t1 -srp "El grupo $nombre fue creado con exito"
                break
            else
                read -n1 -t1 -srp "ERROR: nombre invalido. Use letras, numeros y guiones (sin empezar por los dos ultimos)"
            fi
        fi
    done

    gestion_grupos
}

#-------------------------

#FIN DEL ESPACIO PARA FUNCIONES 
#TODO LO QUE DIGA VOLVER AL MENU PRINCIPAL O RETROCEDER NO ANDA

#COMIENZA LO QE TENGO UQE PEGAR

menu_principal







#TERMINA LO QUE TENGO QUE PEGAR