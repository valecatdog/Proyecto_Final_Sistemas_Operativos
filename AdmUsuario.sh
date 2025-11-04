#!/bin/bash
#ARCHIVO PARA PRUEBAS DEL SCRIPT COMPLETO

#ACTUALMENTE TRABAJANDO EN:
: '
-hacer que ande para 2 parametros
'

#SUGERENCIAS
: '


-verificar que los usuarios/grupos no coincidan con cosas que no se deberian borrar (cosas que vienen con el sistema)
'

#EXPLICACIONES
: '
-los read tienen -r para que no se intrprete lo que se escriba (el shell )
'

export LC_ALL=es_ES.UTF-8
: '
le dice al shell que use es_ES.UTF-8 como codificación para todo. lo agregamos poruqe funciones como tr [:upper:] [:lower:]
no manejan por si solos la misma cantidad de caracteress y eso genera un problema en la ejecucion
'

#ESPACIO PARA FUNCIONES
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


menu_usuarios_grupos(){
    while true 
    do
        clear
        echo "==GESTION DE USUARIOS Y GRUPOS=="
        printf "\n\n"
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
                return
            ;;

            2)
                #crear/eliminar grupos
                gestion_grupos
                return
            ;;

            3)
            #usuarios&grupos
                gestion_usuarios_grupos
                return
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

    if usuario_existe "$1" && [ "$(id -u "$user" 2>/dev/null)" -ge 1000 ] && [ "$(id -u "$user" 2>/dev/null)" -le 65000 ]
    then
        sudo userdel -r "$user"
        read -n1 -t2 -rsp "Usuario $user ($nombre $apellido) eliminado correctamente del sistema"
        printf "\n"
        return 
    else
         read -n1 -t2 -rsp "ERROR: el usuario $user ($nombre $apellido) no existe en el sistema o es posible trabajar con el"
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
#PROBANDO
    echo "Con qué usuarios desea trabajar? (ingrese sus numeros separados por espacios o nada para volver al menu anterior):"
    #despliega todos los usuarios
    usuariosTrabajar=()

    echo "-T. Todos"
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
    if [ "${#usuariosTrabajar[*]}" -ne 0 ]
    then
        read -rp "opcion/es (no ingrese nada para retroceder): " opciones
        
        #Si no se ingreso nada (te devuelve al menu)
        #aca lo que hice fue poner el if para que si esta vacio te coso
        if [ -z "$opciones" ]
        then   
            archivo_procesar "$archivo"
            return
        else
        #Si sí se ingresaron usuarios
            if echo "$opciones" | grep -qw "T"
            then
                for ((i=0; i<${#usuariosTrabajar[@]}; i++)); do
                    if [ "$1" = add ]; then
                        add_usuario "${usuariosTrabajar[$i]}"
                    else
                        del_usuario "${usuariosTrabajar[$i]}"
                    fi
                done
            fi

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
                fi
            done 
        fi

        archivo_procesar "$archivo"
        return
    else 
        read -n1 -t1 -rsp "No hay usuarios trabajar con esta opcion"
    fi
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
        
        0)
            menu_usuarios_grupos
            return
        ;;
        1)
            add_grupo
            return
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
            if [[ "$nombre" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]] && ! grupo_existe "$nombre"; then
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

gestion_usuarios_grupos(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS=="
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Agregar/borrar los usuarios indivudualmente"
        echo "2. Agregar/borrar los usuarios mediante un archivo"
        printf "\n"
        read -rp "Opcion: " opcionCase12                                                         
        case "$opcionCase12" in
        
        0)
            menu_usuarios_grupos
            return
        ;;
        1)
            admin_usergroup_manual_user
            return
        ;;
        2)
            admin_usergroup_archivo 
            return
        ;;
        *)
            read -n1 -t1 -srp "ERROR: opcion incorrecta"
        ;;
        esac
    done
}

admin_usergroup_manual_user(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        printf "\n\n"
        read -rp "Ingrese el usuario (enter para regresar): " usuario
        
        if [ -z "$usuario" ]
        then
            gestion_usuarios_grupos
            return
        elif [[ $usuario =~ ^[A-Za-z]+$ ]]
        then
        #hay 2 ifs en vez de uno para poder indicarle especificamente al usuario que error hay
            if usuario_existe_user "$usuario"; then
                admin_usergroup_manual_grupo
                return
            else
                read -n1 -t1 -srp "ERROR: el usuario $usuario no existe"  
            fi
        else
            read -n1 -t1 -srp "ERROR: formato de nombre incorrecto"   
        fi
    done
}

admin_usergroup_manual_grupo(){
    while true
    do    
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        echo "*usuario: $usuario"
        printf "\n\n"
        read -rp "Ingrese el grupo (enter para regresar): " grupo
        
        if [ -z "$grupo" ]
        then
            admin_usergroup_manual_user
            return
        elif  [[ "$grupo" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]]
        then
            if grupo_existe "$grupo"; then
                aniadir_quitar_usergrupo "$usuario" "$grupo"
                return
            else
                read -n1 -t1 -srp "ERROR: el grupo $grupo no existe"  
            fi
        else
            read -n1 -t1 -srp "ERROR: formato de nombre incorrecto"   
        fi
    done
}

aniadir_quitar_usergrupo(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        echo "*usuario: $1"
        echo "*grupo: $2"
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Agregarlo al grupo"
        echo "2. Quitarlo del grupo"
        printf "\n"
        read -rp "Opcion: " opcionaniadirQuitar

        case $opcionaniadirQuitar in
            0)
                admin_usergroup_manual_grupo
                return   
            ;;
        
            1)
                if id -nG "$1" | grep -qw "$2"; then
                    read -n1 -t2 -srp "El usuario ya pertenece al grupo" 
                else
                    if sudo gpasswd -a "$1" "$2" &>/dev/null; then
                        read -n1 -t2 -srp "Usuario agregado correctamente" 
                    else
                        read -n1 -t2 -srp "ERROR: no se pudo agregar el usuario al grupo" 
                    fi
                fi
            ;;

            2)
                if sudo gpasswd -d "$1" "$2" 2>/dev/null; then
                    read -n1 -t2 -srp "Usuario eliminado correctamente" 
                else
                    read -n1 -t2 -srp "ERROR: no se pudo eliminar el usuario del grupo" 
                fi 
                gestion_usuarios_grupos
                return
            ;;

            *)
               read -n1 -t1 -srp "ERROR: opcion incorrecta" 
            ;;
        esac
    done
}

admin_usergroup_archivo(){
    while true
    do
        
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS CON ARCHIVO=="
        printf "\n\n"
        read -rp "Ingrese la ruta del archivo (enter para regresar): " archivo
        if [ -z "$archivo" ]; then
            gestion_usuarios_grupos
            return
        else 
            if [ -f "$archivo" ] && [ -r "$archivo" ]
                then
                listaUsuarios=()         
                mapfile -t palabras < <(tr -s '[:space:]' '\n' < "$archivo")

                if [ -n "${palabras[*]}" ]
                then
                    for palabra in "${palabras[@]}"; do
                        if getent passwd "$palabra" > /dev/null; then
                            listaUsuarios+=("$palabra")
                        fi
                    done

                    read -t3 -n2 -srp "DEBUG: usuarios: ${listaUsuarios[*]}"

                    if [ -n "${listaUsuarios[*]}" ]; then
                        admin_usergroup_archivo_grupo
                        return
                    else
                        read -t1 -n2 -srp "ERROR: el archivo no contiene ningun usuario valido"
                    fi
                else
                    read -t1 -n2 -srp "ERROR: el archivo esta vacio"
                fi

            else
                read -t1 -n2 -srp "ERROR: el archivo no existe o no se puede leer" 
            fi
        fi
    done
}

admin_usergroup_archivo_grupo(){
    while true
    do    
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS CON ARCHIVO=="
        echo "*archivo: $archivo"
        printf "\n\n"
        read -rp "Ingrese el grupo (enter para regresar): " grupo
        
        if [ -z "$grupo" ]
        then
            admin_usergroup_archivo
            return
        elif  [[ "$grupo" =~ ^[a-zA-Z_][a-zA-Z0-9_-]+$ ]]
        then
            if grupo_existe "$grupo"; then
                aniadir_quitar_usergrupo_archivo "$archivo" "$grupo"
                return
            else
                read -n1 -t1 -srp "ERROR: el grupo $grupo no existe"  
            fi
        else
            read -n1 -t1 -srp "ERROR: formato de nombre incorrecto"   
        fi
    done
}

aniadir_quitar_usergrupo_archivo(){
    while true
    do
        clear
        echo "==AGREAGAR USUARIOS A GRUPOS CON ARCHIVO=="
        echo "*archivo: $1"
        echo "*grupo: $2"
        printf "\n\n"
        echo "Que desea hacer?"
        printf "\n"
        echo "0. Volver a menu anterior" 
        echo "1. Agregar usuarios al grupo"
        echo "2. Quitarlos del grupo"
        printf "\n"
        read -rp "Opcion: " opcionaniadirQuitar
    

        case $opcionaniadirQuitar in
            0)
                admin_usergroup_archivo_grupo
                return   
            ;;
        
            1)
                noAgregados=()
                for u in "${listaUsuarios[@]}"
                do
                    if ! sudo gpasswd -a "$u" "$2" &>/dev/null; then
                       noAgregados+=("$u")
                    fi
                done
                if [ -n "${noAgregados[*]}" ]
                then
                    read -t2 -n1 -srp "No se puedieron agregar los usuarios: ${noAgregados[*]}"
                else
                    read -t2 -n1 -srp "Usuarios agregados correctamente"
                fi
                gestion_usuarios_grupos
                return
            ;;

            2)
                noBorrados=()
                for u in "${listaUsuarios[@]}"
                do
                    if ! sudo gpasswd -d "$u" "$2" &>/dev/null; then
                        noBorrados+=("$u")  
                    fi 
                done
                if [ -n "${noBorrados[*]}" ]
                    then
                        read -t2 -n1 -srp "No se puedieron agregar los usuarios: ${noBorrados[*]}"
                    else
                        read -t2 -n1 -srp "Usuarios eliminados correctamente"
                fi
                gestion_usuarios_grupos
                return
            ;;

            *)
               read -n1 -t1 -srp "ERROR: opcion incorrecta" 
            ;;
        esac
    done
}

usuario_existe_user(){
    local user
    user="$1"
    if getent passwd "$user" >/dev/null; then
        return 0
    else 
        return 1
    fi
}

grupo_existe(){
    local group
    group="$1"
    if getent group "$group" >/dev/null; then
        return 0
    else 
        return 1
    fi   
}
#TERMINA ESPACIO DE FUNCIONES#########################################################################

#NO SE SI ANDA ESTO, NO LO PROBE DESPUES DE PASAR LAS COSAS A FUNCIONES

#ESTRUCTURA PRINCIPAL---------------------------------
clear
#SI NO SE INGRESAN PARAMETROS
if (($# == 0))
then
    menu_principal

#SI SE INGRESA 1 PARAMETRO
elif (($# == 1))
then
    archivo_procesar "$1" 

#SI SE INGRESAN 2 PARAMETROS
elif (($# == 2))
then
    ingreso_usuario "$1" "$2"

#CANTIDAD INCORRECTA DE PARAMETROS
else
    echo "Se ha ingresado una cantidad invalida de parametros"

#FI DE LA ESTRUCTURA PRINCIPAL
fi