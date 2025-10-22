#! /bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
modo sin parametros
actualmente estoy trabajando en gestion de usuarios, crear usuarios, crear usuarios por consola
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

: '
le dice al shell que use UTF-8 como codificación para todo. lo agregamos poruqe funciones como tr [:upper:] [:lower:]
no manejan por si solos la misma cantidad de caracteress y eso genera un problema en la ejecucion
'

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
        grep -q "^${usuario}:" /etc/passwd
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

#FIN DEL ESPACIO PARA FUNCIONES 

#COMIENZA LO QE TENGO UQE PEGAR
valido="false"
while [ "$valido" = false ]
    do
        echo "Elija el modo al que desea acceder: "
        echo "1. Gestion de usuarios"
        echo "2. Gestion de backups"
        read -rp "Opcion: " opcion
        printf "\n--------------------------------\n\n"
        #el echo no expande el \n, printf si

        case $opcion in
            1)
            #MODO GESTION DE USUARIOS
                valido="true"

                validoOpcion1="false"
                while [ "$validoOpcion1" = false ]
                do
                    echo "Que desea hacer? "
                    echo "1. Crear usuarios"
                    echo "2. Eliminar usuarios"
                    echo "3. Crear un grupo"
                    echo "4. Eliminar un grupo"
                    echo "5. Incorporar usuarios a un grupo"
                    #evitamos la palabra aniadir por si la enie llegara a generar problemas
                    read -rp "Opcion: " opcionCase1
                    printf "\n--------------------------------\n\n"
                    
                    case $opcionCase1 in
                        1)
                        #crear usuarios
                            echo "Crear usuarios"
                            printf "\n"
                            validoOpcion1="true"
                            validoOpcion1_1="false"

                            #COMO SE VA A REPETIR CASI IGUAL PUEDE SER UNA FUNCION
                            while [ "$validoOpcion1_1" = false ]
                            do
                                echo "Como los quiere crear? "
                                echo "1. Ingresando los datos por pantalla (permite un usuario)"
                                echo "2. Con un archivo (permite multiples usuarios)"
                                read -rp "Opcion: " opcionCase1_1
                                printf "\n--------------------------------\n\n"
                                
                                case $opcionCase1_1 in
                                    1)
                                        echo "Crear usuarios por pantalla"
                                        printf "\n"

                                        echo "Ingresar: "
                                        read -rp "nombre: " nombreUsuario
                                        read -rp "apellido: " apellidoUsuario

                                        generar_usuario "$nombreUsuario" "$apellidoUsuario"
                                        #se hace la data del usuario y se guarda en la variable "usuario"
                                        add_usuario $usuario
                                        #se añade al usuario
                                    ;;
                                    2)

                                    ;;
                                    *)
                                        echo "Error: opcion invalida"
                                    ;;
                                esac
                            done

                        ;;
                        2)
                        #eliminar usuarios

                            validoOpcion1="true"
                            echo "Eliminar usuarios"
                            printf "\n"
                        ;;
                        3)
                        #crear un grupo
                        #poner el nombre de la opcion y coso

                            validoOpcion1="true"
                        ;;
                        4)
                        #eliminar un grupo

                            validoOpcion1="true"
                        ;;
                        5)
                        #ingresar usuario a grupo

                            validoOpcion1="true"
                        ;;
                        *)
                            echo "Error: opcion incorrecta"
                        ;;
                    esac

                done
            ;;
            
            2)
            #MODO GESTION DE BACKUPS
            #NO BORRO ESTO PORUQE ME SIRVE DE BASE PARA EL RESTO

                valido="true"
                valido1="false"
                while [ "$valido2" = false ]
                    do
                        echo "Elija el modo al que desea acceder: "
                        echo "1. Gestion de usuarios"
                        echo "2. Gestion de backups"
                        read -rp "Opcion: " opcion
                        printf "\n--------------------------------\n\n"
                        #el echo no expande el \n, printf si
                    done
            ;;
            
            *)
                echo "Error: opcion invalida"
            ;;
        esac

    done







#TERMINA LO QUE TENGO QUE PEGAR