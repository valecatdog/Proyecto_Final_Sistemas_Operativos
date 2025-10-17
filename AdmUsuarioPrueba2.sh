#! /bin/bash
#combino las 2 funciones y pruebo si andan
#PROBLEMAS!!!
: '
sudo pide contraseña
solucoin: ejecutar como sudo
'

add_usuario(){

    #verifico la salida de la funcion, si es distinta a 0 entonces actua
    if ! usuario_existe "$1"
    then
        local usuario
        local nombre
        local apellido
        local letraNombre
        local letraApellido
        local passwd

        #datos del usuario
        usuario="$(echo "$1" | cut -d: -f1)"
        nombre="$(echo "$1" | cut -d: -f2)"
        apellido="$(echo "$1" | cut -d: -f3)"

        echo "!!!!!!!!!!!!DATOS DEL USUARIO: $nombre $apellido $usuario"


        #generar contraseña
        letraNombre=$(echo "$nombre" | tr '[:lower:]' '[:upper]')
        letraApellido=$(echo "$apellido" |tr '[:upper]' '[:lower:]' )
        passwd="{$letraNombre}${letraApellido}#1234"

        echo "!!!!!!!!!!!!!!!!!!!!!!CONTRASEÑA DEL USUARIO: $passwd"

        #ingresar usuario
        sudo useradd -mc "$nombre $apellido" "$usuario"
        echo "$usuario":"$passwd" | sudo chpasswd 
        #chpasswd espera recibir parametros por entrada estandar, por eso el pipe
        #HACER QUE LA CONRASEÑA CADUQUE
        echo "Usuario $usuario creado correctamente"
        
    else
        echo "Error: el usuario ya existe en el sistema"
        #HACER EL LOG
    fi
} 

usuario_existe() {
        local usuario="$1"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #habra que escapar el $
        grep -q "^${usuario}:" /etc/passwd
}

echo "Arranca la prueba--------------------------------------------"

read -rp "nombre del usuario: " nombre
add_usuario "$nombre"

read -rp "nombre del usuario: " nombre
add_usuario "$nombre"