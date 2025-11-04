#!/bin/bash

export LC_ALL=es_ES.UTF-8

menu_principal() {
    valido="false"
    while [ "$valido" = "false" ]; do
        clear
        echo "==ELIJA UN MODO=="
        echo
        echo "CTRL+C. Salir"
        echo "1. Gestion de usuarios y grupos"
        echo "2. Gestion de backups"
        echo
        printf "Opcion: "
        read opcion
        #read no acepta ninguna de las opciones que teniamos en el otro script
        echo
        echo "--------------------------------"
        echo

        case "$opcion" in
            1)
                menu_usuarios_grupos
            ;;
            2)
                valido="true"
                # Cargar el script de backup
                . ./backup.sh
            ;;
            *)
                echo "Error: opción incorrecta"
                #en vez de -t2 usamos sleep
                sleep 2
            ;;
        esac
    done
}

menu_usuarios_grupos() {
    while true; do
        clear
        echo "==GESTION DE USUARIOS Y GRUPOS=="
        echo
        echo
        echo "Que desea hacer?"
        echo
        echo "0. Volver al menu anterior"
        echo "1. Crear o eliminar usuarios"
        echo "2. Crear o eliminar grupos"
        echo "3. Incorporar o remover usuarios de grupos"
        echo
        printf "Opcion: "
        read opcionCase1

        case "$opcionCase1" in
            0)
                menu_principal
                break
            ;;
            1)
                gestion_usuarios
                return
            ;;
            2)
                gestion_grupos
                return
            ;;
            3)
                gestion_usuarios_grupos
                return
            ;;
            *)
                echo "Error: opción incorrecta"
                sleep 2
            ;;
        esac
    done
}

gestion_usuarios() {
    while true; do
        clear
        echo "==GESTION DE USUARIOS=="
        echo
        echo

        echo "Desea ingresar un usuario o un archivo para procesar?"
        echo
        echo "0. Volver a menu anterior"
        echo "1. Ingresar un archivo para procesar"
        echo "2. Ingresar un usuario"
        echo "3. Listar usuarios existentes"
        echo
        printf "Opcion: "
        read opcionCase11

        case "$opcionCase11" in
            0)
                menu_usuarios_grupos
                return 0
            ;;
            1)
                clear
                echo "==PROCESAR UN ARCHIVO=="
                echo
                printf "Ingrese la ruta del archivo a procesar (no ingresar nada para cancelar): "
                read archivo
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
                echo
                printf "Ingrese el nombre y apellido del usuario (no ingresar nada para cancelar): "
                read nombre apellido
                if [ -z "$nombre" ] && [ -z "$apellido" ]; then
                    gestion_usuarios
                    return
                elif [ -n "$nombre" ] && [ -n "$apellido" ]; then
                    ingreso_usuario "$nombre" "$apellido"
                    return
                else
                    echo "ERROR: procure escribir el nombre y el apellido del usuario"
                    sleep 2
                    gestion_usuarios
                    return
                fi
            ;;
            3)
                clear
                echo "==LISTADO DE USUARIOS=="
                echo "*este listado solo contiene usuarios estandar"
                echo
                getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 { print $3 ". " $1 }'
                echo
                printf "------Presione Enter para continuar------"
                read dummy
                #pausa de un caracter
            ;;
            *)
                echo "ERROR: opción incorrecta"
                sleep 2
                clear
            ;;
        esac
    done
}

generar_usuario() {
    #no se usa local
    nombre="$1"
    apellido="$2"
    primeraLetra=$(echo "$nombre" | cut -c1)
    user="${primeraLetra}${apellido}"
    usuario_completo="${nombre}:${apellido}:$user"
}

usuario_existe() {
    #eliminamos local
    user="$(echo "$1" | cut -d: -f3)"
    if getent passwd "$user" >/dev/null; then
        return 0
    else 
        return 1
    fi
}

add_usuario() {
    nombre=$(echo "$1" | cut -d: -f1)
    apellido=$(echo "$1" | cut -d: -f2)
    user=$(echo "$1" | cut -d: -f3)

    if ! usuario_existe "$1"; then
        letraNombre=$(echo "$nombre" | cut -c1 | tr '[:lower:]' '[:upper:]')
        letraApellido=$(echo "$apellido" | cut -c1 | tr '[:upper:]' '[:lower:]')
        passwd="${letraNombre}${letraApellido}#123456"

        sudo useradd -mc "$nombre $apellido" "$user"
        echo "$user:$passwd" | sudo chpasswd
        sudo chage -d 0 "$user"

        printf "Usuario %s creado correctamente. Contraseña: %s\n" "$user" "$passwd"
        #%s se va a reemplazar por un string, se le especifica aca arriba ^
        printf "Presione Enter para continuar..."
        read
        return
    else
        printf "Error: el usuario %s (%s %s) ya existe en el sistema\n" "$user" "$nombre" "$apellido"
        echo "$1" >> cre_usuarios.log
        printf "Presione Enter para continuar..."
        read
        return
    fi
}

del_usuario() {
    nombre=$(echo "$1" | cut -d: -f1)
    apellido=$(echo "$1" | cut -d: -f2)
    user=$(echo "$1" | cut -d: -f3)

    if usuario_existe "$1" && [ "$(id -u "$user" 2>/dev/null)" -ge 1000 ] && [ "$(id -u "$user" 2>/dev/null)" -le 65000 ]; then
        sudo userdel -r "$user"
        printf "Usuario %s (%s %s) eliminado correctamente del sistema\n" "$user" "$nombre" "$apellido"
        printf "Presione Enter para continuar..."
        read
        return
    else
        printf "ERROR: el usuario %s (%s %s) no existe en el sistema o no se puede trabajar con él\n" "$user" "$nombre" "$apellido"
        printf "Presione Enter para continuar..."
        read
        return
    fi
}

ingreso_usuario() {
    nombre="$1"
    apellido="$2"

    # Validar que nombre y apellido solo contengan letras
    case "$nombre$apellido" in
        *[!A-Za-z]*)
            printf "ERROR: formato de nombres incorrecto\n"
            printf "Presione Enter para continuar..."
            read
            gestion_usuarios
            return
        ;;
    esac

    while true; do
        generar_usuario "$nombre" "$apellido"
        clear
        echo "==INGRESAR UN USUARIO=="
        echo
        echo "Que desea hacer?"
        echo "0. Volver al menu de gestion usuarios"
        echo "1. Crear usuario"
        echo "2. Eliminar usuario del sistema"
        echo
        printf "Elija una opcion: "
        read opcion

        if [ "$opcion" -eq 0 ] 2>/dev/null; then
            gestion_usuarios
            return
        elif [ "$opcion" -eq 1 ] 2>/dev/null; then
            add_usuario "$usuario_completo" >/dev/null
        elif [ "$opcion" -eq 2 ] 2>/dev/null; then
            del_usuario "$usuario_completo" >/dev/null
        else
            printf "Error: opcion invalida\n"
            sleep 2
        fi
    done
}

verificar_archivo() {
    clear
    archivo="$1"

    while true; do
        if [ -f "$archivo" ] && [ -r "$archivo" ] && grep -qE '^[[:alpha:]]+[[:space:]]+[[:alpha:]]+' "$archivo"; then
            return 0
        elif [ -z "$archivo" ]; then
            return 1
        else
            echo "==PROCESAR UN ARCHIVO=="
            echo
            echo "Error: archivo invalido o no encontrado"
            printf "Ingrese una ruta válida (no ingresar nada para cancelar): "
            read archivo
            clear
        fi
    done
}

archivo_procesar() {
    listaUsuarios=""
    archivo="$1"

    if ! verificar_archivo "$archivo"; then
        gestion_usuarios
        return
    else
        # Leer archivo línea por línea usando awk y while
        awk 'NF >= 2 {print $1, $2}' "$archivo" | while read nombre apellido; do
            #reemplazamos < <(awk..) por un pipe
            generar_usuario "$nombre" "$apellido"
            listaUsuarios="$listaUsuarios $usuario_completo"
            #en vez de lsita es un string separado por espacios
        done

        while true; do
            clear
            echo "==PROCESAR UN ARCHIVO=="
            echo "*archivo: $archivo"
            echo
            echo "Que desea hacer?"
            echo "0. Volver al menu de gestion de usuarios"
            echo "1. Crear usuarios"
            echo "2. Eliminar usuarios del sistema"
            echo
            printf "Opcion: "
            read opcion

            case "$opcion" in
                0)
                    gestion_usuarios
                    return
                ;;
                1)
                    archivo_procesar_addDel "add"
                    archivo_procesar "$archivo"
                    return
                ;;
                2)
                    archivo_procesar_addDel "del"
                    archivo_procesar "$archivo"
                    return
                ;;
                *)
                    echo "Asegurese de elegir un valor válido"
                    sleep 2
                ;;
            esac
        done
    fi
}

archivo_procesar_addDel() {
    usuariosTrabajar=""
    ind=0
    clear
    echo "==PROCESAR UN ARCHIVO=="
    echo
    if [ "$1" = "add" ]; then
        echo "Elegido: 1. Crear usuarios"
    else
        echo "Elegido: 2. Eliminar usuarios del sistema"
    fi

    echo "Con qué usuarios desea trabajar? (ingrese sus numeros separados por espacios o nada para volver al menu anterior):"
    echo "-T. Todos"

    # Mostrar usuarios disponibles
    for usuario in $listaUsuarios; do
        nombre=$(echo "$usuario" | cut -d: -f1)
        apellido=$(echo "$usuario" | cut -d: -f2)
        user=$(echo "$usuario" | cut -d: -f3)

        if [ "$1" = "add" ] && ! getent passwd "$user" >/dev/null; then
            echo "$ind. $user ($nombre $apellido)"
            usuariosTrabajar="$usuariosTrabajar $usuario"
            ind=$((ind + 1))
        elif [ "$1" = "del" ] && getent passwd "$user" >/dev/null; then
            echo "$ind. $user ($nombre $apellido)"
            usuariosTrabajar="$usuariosTrabajar $usuario"
            ind=$((ind + 1))
        fi
    done

    if [ -n "$usuariosTrabajar" ]; then
        printf "opcion/es (no ingrese nada para retroceder): "
        read opciones

        if [ -z "$opciones" ]; then
            archivo_procesar "$archivo"
            return
        fi

        # Comprobar si eligieron "T" (todos)
        case "$opciones" in
            *T*)
                for usuario in $usuariosTrabajar; do
                    if [ "$1" = "add" ]; then
                        add_usuario "$usuario"
                    else
                        del_usuario "$usuario"
                    fi
                done
            ;;
        esac

        # Limpiar espacios múltiples
        opciones=$(echo "$opciones" | tr -s ' ')

        # Procesar opciones numéricas
        i=0
        for usuario in $usuariosTrabajar; do
            usuariosIndex="$usuariosIndex $i:$usuario"
            i=$((i + 1))
        done

        for opcion in $opciones; do
            case "$opcion" in
                ''|*[!0-9]*)
                    # no es un número, ignorar
                ;;
                *)
                    # Buscar el usuario correspondiente al índice
                    for item in $usuariosIndex; do
                        idx=$(echo "$item" | cut -d: -f1)
                        usr=$(echo "$item" | cut -d: -f2-)
                        if [ "$opcion" -eq "$idx" ]; then
                            if [ "$1" = "add" ]; then
                                add_usuario "$usr"
                            else
                                del_usuario "$usr"
                            fi
                        fi
                    done
                ;;
            esac
        done

        archivo_procesar "$archivo"
        return
    else
        echo "No hay usuarios para trabajar con esta opcion"
        sleep 2
    fi
}

gestion_grupos() {
    while true; do
        clear
        echo "==GESTION DE GRUPOS=="
        echo
        echo
        echo "Que desea hacer?"
        echo
        echo "0. Volver a menu anterior"
        echo "1. Crear grupos"
        echo "2. Eliminar grupos"
        echo "3. Listar grupos existentes"
        echo
        printf "Opcion: "
        read opcionCase12

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
                echo "*este listado solo contiene grupos estandar"
                echo
                getent group | awk -F: '$3 >= 1000 && $3 <= 60000 { print $3 ". " $1 }'
                echo
                printf "------Presione Enter para continuar------"
                read
            ;;
            *)
                echo "ERROR: opcion incorrecta"
                sleep 2
            ;;
        esac
    done
}

del_grupo() {
    clear
    echo "==GESTION DE GRUPOS=="
    echo "Eliminar un grupo"
    echo

    # Leer grupos estándar en una lista separada por espacios
    listaGrupos=""
    getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' | while read grp; do
        listaGrupos="$listaGrupos $grp"
    done

    # Mostrar grupos con índices
    i=0
    for grp in $listaGrupos; do
        echo "$i. $grp"
        i=$((i + 1))
    done

    echo
    set -f
    printf "opcion/es (no ingrese nada para retroceder): "
    read opciones

    if [ -z "$opciones" ]; then
        gestion_grupos
        return
    fi

    opciones=$(echo "$opciones" | tr -s ' ')
    opcionesInvalidas=""

    # Construir lista indexada para POSIX
    i=0
    gruposIndex=""
    for grp in $listaGrupos; do
        gruposIndex="$gruposIndex $i:$grp"
        i=$((i + 1))
    done

    # Procesar opciones
    for opcion in $opciones; do
        case "$opcion" in
            ''|*[!0-9]*)
                opcionesInvalidas="$opcionesInvalidas $opcion"
            ;;
            *)
                # Buscar grupo correspondiente al índice
                for item in $gruposIndex; do
                    idx=$(echo "$item" | cut -d: -f1)
                    gname=$(echo "$item" | cut -d: -f2-)
                    if [ "$opcion" -eq "$idx" ]; then
                        sudo groupdel "$gname"
                        printf "Se ha eliminado el grupo %s con exito\n" "$gname"
                        printf "Presione Enter para continuar..."
                        read
                    fi
                done
            ;;
        esac
    done

    if [ -n "$opcionesInvalidas" ]; then
        printf "Las opciones invalidas ingresadas fueron: %s\n" "$opcionesInvalidas"
        printf "Presione Enter para continuar..."
        read
    fi

    gestion_grupos
}

add_grupo() {
    while true; do
        clear
        echo "==GESTION DE GRUPOS=="
        echo "Crear un grupo"
        echo

        printf "Nombre del grupo (no ingrese nada para retroceder): "
        read nombre

        if [ -z "$nombre" ]; then
            gestion_grupos
            return
        fi

        # Validar nombre de grupo: solo letras, números, guiones y guion bajo; no empezar con número ni guion
        case "$nombre" in
            [a-zA-Z_]*)
                if grupo_existe "$nombre"; then
                    printf "ERROR: el grupo %s ya existe\n" "$nombre"
                    printf "Presione Enter para continuar..."
                    read
                else
                    sudo groupadd "$nombre"
                    printf "El grupo %s fue creado con exito\n" "$nombre"
                    printf "Presione Enter para continuar..."
                    read
                    break
                fi
            ;;
            *)
                printf "ERROR: nombre invalido. Use letras, numeros, guiones o guion bajo (sin empezar por numero ni guion)\n"
                printf "Presione Enter para continuar..."
                read
            ;;
        esac
    done

    gestion_grupos
}

gestion_usuarios_grupos() {
    while true; do
        clear
        echo "==AGREGAR USUARIOS A GRUPOS=="
        echo
        echo
        echo "Que desea hacer?"
        echo
        echo "0. Volver a menu anterior"
        echo "1. Agregar/borrar los usuarios individualmente"
        echo "2. Agregar/borrar los usuarios mediante un archivo"
        echo
        printf "Opcion: "
        read opcionCase12

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
                echo "ERROR: opcion incorrecta"
                sleep 2
            ;;
        esac
    done
}

admin_usergroup_manual_user() {
    while true; do
        clear
        echo "==AGREGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        echo
        echo

        # CAMBIO: Reemplazado 'read -rp' (no POSIX) por printf + read
        printf "Ingrese el usuario (enter para regresar): "
        read usuario

        if [ -z "$usuario" ]; then
            gestion_usuarios_grupos
            return
        fi

        # CAMBIO: Reemplazado '[[ $usuario =~ ^[A-Za-z]+$ ]]' (no POSIX) por case
        case "$usuario" in
            # Solo letras mayúsculas y minúsculas
            *[!A-Za-z]*)
                # CAMBIO: Reemplazado 'read -n1 -t1 -srp' por echo + sleep + read
                echo "ERROR: formato de nombre incorrecto"
                sleep 2
            ;;
            *)
                if usuario_existe_user "$usuario"; then
                    admin_usergroup_manual_grupo
                    return
                else
                    # CAMBIO: Reemplazado 'read -n1 -t1 -srp' por echo + sleep + read
                    echo "ERROR: el usuario $usuario no existe"
                    sleep 2
                fi
            ;;
        esac
    done
}

admin_usergroup_manual_grupo() {
    while true; do
        clear
        echo "==AGREGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        echo "*usuario: $usuario"
        echo
        echo

        # CAMBIO: Reemplazado 'read -rp' (no POSIX) por printf + read
        printf "Ingrese el grupo (enter para regresar): "
        read grupo

        if [ -z "$grupo" ]; then
            admin_usergroup_manual_user
            return
        fi

        # CAMBIO: Reemplazado '[[ ... =~ ... ]]' (no POSIX) por case para validar nombre de grupo
        case "$grupo" in
            # Debe empezar con letra o guion bajo y contener solo letras, numeros, guion bajo o guion medio
            [a-zA-Z_]*)
                if grupo_existe "$grupo"; then
                    aniadir_quitar_usergrupo "$usuario" "$grupo"
                    return
                else
                    # CAMBIO: Reemplazado 'read -n1 -t1 -srp' por echo + sleep
                    echo "ERROR: el grupo $grupo no existe"
                    sleep 2
                fi
            ;;
            *)
                # CAMBIO: Reemplazado 'read -n1 -t1 -srp' por echo + sleep
                echo "ERROR: formato de nombre incorrecto"
                sleep 2
            ;;
        esac
    done
}

aniadir_quitar_usergrupo() {
    while true; do
        clear
        echo "==AGREGAR USUARIOS A GRUPOS INDIVIDUALMENTE=="
        echo "*usuario: $1"
        echo "*grupo: $2"
        echo
        echo
        echo "Que desea hacer?"
        echo
        echo "0. Volver a menu anterior"
        echo "1. Agregarlo al grupo"
        echo "2. Quitarlo del grupo"
        echo

        # CAMBIO: Reemplazado 'read -rp' por printf + read
        printf "Opcion: "
        read opcionaniadirQuitar

        case "$opcionaniadirQuitar" in
            0)
                admin_usergroup_manual_grupo
                return
            ;;
            1)
                # CAMBIO: Reemplazado 'read -n1 -t2 -srp' por echo + sleep
                if id -nG "$1" | grep -qw "$2"; then
                    echo "El usuario ya pertenece al grupo"
                    sleep 2
                else
                    if sudo gpasswd -a "$1" "$2" >/dev/null 2>&1; then
                        echo "Usuario agregado correctamente"
                        sleep 2
                    else
                        echo "ERROR: no se pudo agregar el usuario al grupo"
                        sleep 2
                    fi
                fi
            ;;
            2)
                if sudo gpasswd -d "$1" "$2" >/dev/null 2>&1; then
                    echo "Usuario eliminado correctamente"
                    sleep 2
                else
                    echo "ERROR: no se pudo eliminar el usuario del grupo"
                    sleep 2
                fi
                gestion_usuarios_grupos
                return
            ;;
            *)
                # CAMBIO: Reemplazado 'read -n1 -t1 -srp' por echo + sleep
                echo "ERROR: opcion incorrecta"
                sleep 2
            ;;
        esac
    done
}

admin_usergroup_archivo() {
    while true; do
        clear
        echo "==AGREGAR USUARIOS A GRUPOS CON ARCHIVO=="
        echo
        echo

        # CAMBIO: Reemplazado 'read -rp' por printf + read
        printf "Ingrese la ruta del archivo (enter para regresar): "
        read archivo

        if [ -z "$archivo" ]; then
            gestion_usuarios_grupos
            return
        fi

        if [ -f "$archivo" ] && [ -r "$archivo" ]; then
            # CAMBIO: Eliminado mapfile y arrays, usamos lista separada por espacios
            listaUsuarios=""
            while read palabra; do
                # CAMBIO: Validamos usuario con getent
                if getent passwd "$palabra" >/dev/null 2>&1; then
                    listaUsuarios="$listaUsuarios $palabra"
                fi
            done < "$archivo"

            if [ -n "$listaUsuarios" ]; then
                admin_usergroup_archivo_grupo
                return
            else
                # CAMBIO: Reemplazado read -t1 -n2 -srp por echo + sleep
                echo "ERROR: el archivo no contiene ningun usuario valido"
                sleep 2
            fi
        else
            # CAMBIO: Reemplazado read -t1 -n2 -srp por echo + sleep
            echo "ERROR: el archivo no existe o no se puede leer"
            sleep 2
        fi
    done
}

admin_usergroup_archivo_grupo() {
    while true; do
        clear
        echo "==AGREGAR USUARIOS A GRUPOS CON ARCHIVO=="
        echo "*archivo: $archivo"
        echo
        echo

        # CAMBIO: Reemplazado 'read -rp' por printf + read
        printf "Ingrese el grupo (enter para regresar): "
        read grupo

        if [ -z "$grupo" ]; then
            admin_usergroup_archivo
            return
        fi

        # CAMBIO: Reemplazado '[[ ... =~ ... ]]' (no POSIX) por case
        case "$grupo" in
            [a-zA-Z_]*)
                if grupo_existe "$grupo"; then
                    aniadir_quitar_usergrupo_archivo "$archivo" "$grupo"
                    return
                else
                    # CAMBIO: Reemplazado 'read -n1 -t1 -srp' por echo + sleep
                    echo "ERROR: el grupo $grupo no existe"
                    sleep 2
                fi
            ;;
            *)
                # CAMBIO: Reemplazado 'read -n1 -t1 -srp' por echo + sleep
                echo "ERROR: formato de nombre incorrecto"
                sleep 2
            ;;
        esac
    done
}

aniadir_quitar_usergrupo_archivo() {
    while true; do
        clear
        echo "==AGREGAR USUARIOS A GRUPOS CON ARCHIVO=="
        echo "*archivo: $1"
        echo "*grupo: $2"
        echo
        echo
        echo "Que desea hacer?"
        echo
        echo "0. Volver a menu anterior"
        echo "1. Agregar usuarios al grupo"
        echo "2. Quitarlos del grupo"
        echo

        # CAMBIO: Reemplazado 'read -rp' por printf + read
        printf "Opcion: "
        read opcionaniadirQuitar

        case "$opcionaniadirQuitar" in
            0)
                admin_usergroup_archivo_grupo
                return
            ;;
            1)
                # CAMBIO: Reemplazado arrays por lista separada por espacios
                noAgregados=""
                for u in $listaUsuarios; do
                    # CAMBIO: Reemplazado &>/dev/null por >/dev/null 2>&1
                    if ! sudo gpasswd -a "$u" "$2" >/dev/null 2>&1; then
                        noAgregados="$noAgregados $u"
                    fi
                done

                # CAMBIO: Reemplazado read -t2 -n1 -srp por echo + sleep
                if [ -n "$noAgregados" ]; then
                    echo "No se pudieron agregar los usuarios:$noAgregados"
                    sleep 2
                else
                    echo "Usuarios agregados correctamente"
                    sleep 2
                fi
                gestion_usuarios_grupos
                return
            ;;
            2)
                # CAMBIO: Reemplazado arrays por lista separada por espacios
                noBorrados=""
                for u in $listaUsuarios; do
                    if ! sudo gpasswd -d "$u" "$2" >/dev/null 2>&1; then
                        noBorrados="$noBorrados $u"
                    fi
                done

                # CAMBIO: Reemplazado read -t2 -n1 -srp por echo + sleep
                if [ -n "$noBorrados" ]; then
                    echo "No se pudieron eliminar los usuarios:$noBorrados"
                    sleep 2
                else
                    echo "Usuarios eliminados correctamente"
                    sleep 2
                fi
                gestion_usuarios_grupos
                return
            ;;
            *)
                # CAMBIO: Reemplazado read -n1 -t1 -srp por echo + sleep
                echo "ERROR: opcion incorrecta"
                sleep 2
            ;;
        esac
    done
}

usuario_existe_user() {
    user="$1"   # CAMBIO: se eliminó 'local', POSIX no lo soporta
    if getent passwd "$user" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

grupo_existe() {
    group="$1"  # CAMBIO: se eliminó 'local', POSIX no lo soporta
    if getent group "$group" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}
clear

if [ "$#" -eq 0 ]; then
    menu_principal

elif [ "$#" -eq 1 ]; then
    archivo_procesar "$1"

elif [ "$#" -eq 2 ]; then
    ingreso_usuario "$1" "$2"

else
    echo "Se ha ingresado una cantidad invalida de parametros"
fi
