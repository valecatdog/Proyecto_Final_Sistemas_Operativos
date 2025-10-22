#! /bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
-para un usuario
'

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
        grep -q "^${usuario}:" /etc/passwd
}



if  (($# == 1))
then
    echo "lo pusiste mal amiga"

#LO QUE TENGO QUE COPIAR    

elif (($# == 2))
then
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
            printf "\n----------------------------\n"
            echo "Error: opcion invalida"
            printf "\n----------------------------\n"
        fi
    done



#TEMRINA LO QUE TEGO QE COPIAR  
fi