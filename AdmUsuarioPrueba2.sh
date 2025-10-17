#! /bin/bash
#combino las 2 funciones y pruebo si andan
#PROBLEMAS!!!
: '
cuando metes un usuario que ya esxste t deja igual

'

export LC_ALL=C.UTF-8

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
        #SE PUEDE MEJORRAR ENCONTGRANDO UNA MANERA DE QEU DUNCIONE PARA CARACTERES ESPECIALES (pero rocky no aguanta [:upper:] y [:lower:])
        letraNombre=$(echo "$nombre" | cut -c1 | tr a-z A-Z)
        letraApellido=$(echo "$apellido" | cut -c1 | tr A-Z a-z)
        passwd="${letraNombre}${letraApellido}#1234"

        echo "!CONTRASEÑA: $passwd"
        #ingresar usuario
        sudo useradd -mc "$nombre $apellido" "$usuario"
        echo "$usuario":"$passwd" | sudo chpasswd 
        #chpasswd espera recibir parametros por entrada estandar, por eso el pipe
        sudo chage -d 0 "$usuario"
        #hace ruqe la contraseña expire inmediatamente
        echo "Usuario $usuario creado correctamente"
        
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


read -rp "amigA!! mete tu usuario con le formato nombre:apellido:usuario:  " coso
add_usuario "$coso"