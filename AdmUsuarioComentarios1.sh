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

#FALTA PARTE ARU
menu_principal(){
    #mientras la variable valido sea falsa se ejecuta el while (permite ingresar opciones incorrectas y seguir)
    valido="false"
    while [ "$valido" = false ]
        do
            #menu
            clear
            #clear limpia la pantalla. asi queda mas prolijo
            echo "==ELIJA UN MODO== "
            printf "\n"
            echo "CTRL+C. Salir"
            echo "1. Gestion de usuarios y grupos"
            echo "2. Gestion de backups"
            printf "\n"
            read -rp "Opcion: " opcion
            #r es raw (no expande \), p para mostrar texto
            printf "\n--------------------------------\n\n"
            #el echo no expande el \n, printf si

            #segun el valor de opcion lo que se haga
            case $opcion in
            #usamos numeros en los case por comodidad, podria haber sido perfectamente letras como a b c
                1)
                    #si es 1, se manda el menu usuaris grupos
                    menu_usuarios_grupos
                    return
                    #return para asegurarnos de que no siga corriendo esta funcion despues de ido al otro menu
                ;;
                
                2)
                #MODO GESTION DE BACKUPS,  LO HACER ARU
                    valido="true"
                    echo "te extraño"
                ;;
                
                #si se ingresa cualquier cosa que no sea de las que se especifico hace esto
                *)
                    read -t2 -n1 -rsp "Error: opción incorrecta" 
                    : 't (timeout): tiempo de espera; -n (num. of char.): permite escribir sol un caracter. es util porque si el usuario
                    toca una tecla puede terminar el tiempo de espera antes, y previene que lo que el usuario escriba
                    se quede guardado para el proximo read (o sea ue limpia la entrada y previene errores); -s (secret/
                    silent): no muestra lo que escribe el usuario; -r (raw): no interpreta; -p (prompt): muestra el texto
                    '
                ;;
        esac    
    #cierre del case
     done
     #cierre del while

}


menu_usuarios_grupos(){
    #un while uqe se ejecuta por siempre. como usamos funciones y return para salir, el while se va a cortar
    #(no es necesaria una variable)
    while true 
    do
        #menu
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
        
        #las variables que see van a switchear en el case tienen distintos nombres cada vez para
        #evitar errores
        case $opcionCase1 in
        #tambien usamos numeros en el case
            0)
            #funciona como el case anterior y todos los demas case
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
    #lo mismo que el anterior. no pusimos el do al costado por nada en particular 
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
                #-n es si NO esta vacio
                    archivo_procesar "$archivo"
                    #le pasamos una variable como parametro para que trabaje con ella
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
                    #-z significa "si esta vacio"
                    then
                        gestion_usuarios
                        return
                    elif [ -n "$nombre" ] && [ -n "$apellido" ]
                    #elif es "else if", otro if
                    #-n es "si NO esta vacio"
                    then
                        ingreso_usuario "$nombre" "$apellido"
                        #aca le pasamos variables como parametros a una funcion para que trabaje con ellas
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

usuario_existe() {
    local user
    user="$(echo "$1" | cut -d: -f3)"
    #como el fomato es nombre:apellido:user necesitamos el 3er campo
    if getent passwd "$user" >/dev/null; then
        #lo buscamos en passwd
        return 0
        #si lo encontro, retorna 0 (sin errores)
    else 
        return 1
        #si no, retorna 1 (error)
    fi
}

add_usuario(){
    local user
    local nombre
    local apellido

    nombre="$(echo "$1" | cut -d: -f1)"
    apellido="$(echo "$1" | cut -d: -f2)"
    user="$(echo "$1" | cut -d: -f3)"
    #comsigo nombre apellido user

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
        #se agrega el nombre al final del log
        return
    fi
}

del_usuario(){
    local nombre
    local apellido
    local user

    nombre=$(echo "$1" | cut -d: -f1)
    apellido=$(echo "$1" | cut -d: -f2)
    user=$(echo "$1" | cut -d: -f3)
    #extraemos nombre, apellido y nombre de usuario desde el parámetro $1 (formato: nombre:apellido:user)

    if usuario_existe "$1" && [ "$(id -u "$user" 2>/dev/null)" -ge 1000 ] && [ "$(id -u "$user" 2>/dev/null)" -le 65000 ]
    then
        #verificamos que el usuario exista y que su UID esté en el rango de usuarios normales (1000-65000)
        
        sudo userdel -r "$user"
        : 'userdel elimina al usuario del sistema.
        -r elimina también su directorio home y archivos del spool de correo.
        Se usa sudo para asegurarse de tener permisos, aunque el script debería ejecutarse con privilegios adecuados.
        '
        
        read -n1 -t2 -rsp "Usuario $user ($nombre $apellido) eliminado correctamente del sistema"
        #mensaje al usuario indicando que la eliminación fue exitosa
        #-n1: lee solo un caracter
        #-t2: espera máximo 2 segundos
        #-r: no interpreta escapes
        #-s: no muestra lo que se escribe
        #-p: mensaje a mostrar

        printf "\n"
        return
    else
        read -n1 -t2 -rsp "ERROR: el usuario $user ($nombre $apellido) no existe en el sistema o es posible trabajar con el"
        #mensaje de error si el usuario no existe o si su UID no está en el rango permitido
        printf "\n"
        return
    fi
}

ingreso_usuario(){
    local nombre
    local apellido
    nombre="$1"
    apellido="$2"

    if [[ "$nombre" =~ ^[A-Za-z]+$  && "$apellido" =~ ^[A-Za-z]+$ ]]
    then
    #verificamos que tanto nombre como apellido contengan solo letras (mayusculas o minusculas)
    #lso doble parentesis permiten regex =~ es el simbolo qeu se usa para comparar
        until false
        #lo mismo que un while true 
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
            #llamamos a la funcion generar_usuario pasando nombre y apellido

            listaUsuarios+=("$usuario_completo")
            #agregamos el usuario completo (generado por la funcion) al array listaUsuarios
        done < <(awk 'NF >= 2 {print $1, $2}' "$archivo")
        #: 'awk procesa el archivo y devuelve solo las lineas con al menos 2 campos
        # y extrae el primer y segundo campo (nombre y apellido) para ser leidos por el while


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
    #creo un array
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

    echo "-T. Todos"
    for ((i = 0; i < ${#listaUsuarios[@]}; i++)); do
        IFS=':' read -r nombre apellido user <<< "${listaUsuarios[i]}"
        #separamos cada elemento del array listaUsuarios en nombre, apellido y usuario usando ':' como separador

        if ! getent passwd "$user" > /dev/null && [ "$1" = add ]
        then
            echo "$ind. $user ($nombre $apellido)"
            #mostramos el indice y los datos del usuario que se puede agregar

            usuariosTrabajar+=("${listaUsuarios["$i"]}")
            #agregamos el usuario al array de usuarios a trabajar

            ind=$((ind+1))
            #incrementamos el indice
        elif getent passwd "$user" > /dev/null && [ "$1" = del ]
        then
            echo "$ind. $user ($nombre $apellido)"
            #mostramos el indice y los datos del usuario que se puede eliminar

            usuariosTrabajar+=("${listaUsuarios["$i"]}")
            #agregamos el usuario al array de usuarios a trabajar

            ind=$((ind+1))
            #incrementamos el indice
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
            #w es solo para si se ingreso T no pegada a nada
            then
                for ((i=0; i<${#usuariosTrabajar[@]}; i++)); do
                    if [ "$1" = add ]; then
                    #si es add, aniade al usuarios de al posicion i
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
                #el # espara uqe te diga el numero de elemntro qe tiene. verificamos que vaya de 0 a 9
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
            # awk filtra grupos por ID (1000-60000) y muestra numero y nombre
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
    # mapfile crea array con nombres de grupos del sistema
    mapfile -t listaGrupos < <(getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
    # awk -F: divide por campos usando : como separador
    # $3 >= 1000 && $3 < 60000 filtra por ID de grupo
    # {print $1} muestra solo el nombre del grupo
    
    echo "Que grupos desea eliminar? (ingrese sus numeros separados por espacios):"

    # bucle para mostrar lista numerada de grupos
    for ((i=0; i<${#listaGrupos[@]}; i++)); do
        echo "${i}. ${listaGrupos[$i]}"
    done
    
    printf "\n"
    set -f  # desactiva expansion de comodines
    read -rp "opcion/es (no ingrese nada para retroceder): " opciones
    
    # verifica si no se ingreso nada
    if [ -z "$opciones" ]
    then   
        gestion_grupos
        return
    else
        # limpia espacios multiples
        opciones=$(echo "$opciones" | tr -s ' ')
        opcionesInvalidas=""
        
        # procesa cada opcion ingresada
        for opcion in $opciones; do
            # verifica si opcion es numero valido
            if  [[ "$opcion" =~ ^[0-9]+$ ]] && (( "$opcion" >= 0 && "$opcion" < ${#listaGrupos[@]})) > /dev/null; then 
                sudo groupdel "${listaGrupos["$opcion"]}"
                read -n1 -t1 -srp "Se ha eliminado el grupo $opcion con exito"
            else
                opcionesInvalidas+=" $opcion"
            fi
        done
        
        # maneja opciones invalidas
        if [ -n "$opcionesInvalidas" ]
        then
            read -n1 -t1 -rsp "Las opciones invalidas ingresadas fueron: $(echo "$opcionesInvalidas" | sort | uniq 2>/dev/null)"
            opcionesInvalidas=""
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

        # verifica si se presiono enter sin texto
        if [ -z "$nombre" ]
        then
            gestion_grupos
            return
        else
            # regex valida formato de nombre: letra/guion bajo al inicio, luego alfanumerico/guiones
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
            # verifica existencia de usuario
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
            # verifica existencia del grupo
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
                # verifica si usuario ya esta en el grupo
                if id -nG "$1" | grep -qw "$2"; then
                    read -n1 -t2 -srp "El usuario ya pertenece al grupo" 
                else
                    # agrega usuario al grupo con gpasswd
                    if sudo gpasswd -a "$1" "$2" &>/dev/null; then
                        read -n1 -t2 -srp "Usuario agregado correctamente" 
                    else
                        read -n1 -t2 -srp "ERROR: no se pudo agregar el usuario al grupo" 
                    fi
                fi
            ;;

            2)
                # elimina usuario del grupo con gpasswd
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
            # verifica que archivo exista y sea legible
            if [ -f "$archivo" ] && [ -r "$archivo" ]
                then
                listaUsuarios=()         
                # mapfile lee archivo y separa palabras por espacios
                mapfile -t palabras < <(tr -s '[:space:]' '\n' < "$archivo")

                if [ -n "${palabras[*]}" ]
                then
                    # procesa cada palabra del archivo
                    for palabra in "${palabras[@]}"; do
                        # verifica si palabra es usuario existente
                        if getent passwd "$palabra" > /dev/null; then
                            listaUsuarios+=("$palabra")
                        fi
                    done

                    read -t3 -n2 -srp "DEBUG: usuarios: ${listaUsuarios[*]}"

                    # verifica si se encontraron usuarios validos
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
            # verifica existencia del grupo
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
                # procesa cada usuario de la lista
                for u in "${listaUsuarios[@]}"
                do
                    # intenta agregar usuario al grupo
                    if ! sudo gpasswd -a "$u" "$2" &>/dev/null; then
                       noAgregados+=("$u")
                    fi
                done
                # maneja usuarios que no se pudieron agregar
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
                # procesa cada usuario de la lista
                for u in "${listaUsuarios[@]}"
                do
                    # intenta eliminar usuario del grupo
                    if ! sudo gpasswd -d "$u" "$2" &>/dev/null; then
                        noBorrados+=("$u")  
                    fi 
                done
                # maneja usuarios que no se pudieron eliminar
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

# funcion para verificar existencia de usuario
usuario_existe_user(){
    local user
    user="$1"
    if getent passwd "$user" >/dev/null; then
        return 0
    else 
        return 1
    fi
}

# funcion para verificar existencia de grupo
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