#! /bin/bash

#escrctura del usuario:
#nombre:apellido:usuario

del_usuario(){
    if usuario_existe "$1"
    then
        local nombre
        local apellido
        local usuario
        
        nombre=$(echo "$1" | cut -d: -f1)
        apellido=$(echo "$1" | cut -d: -f2)
        usuario=$(echo "$1" | cut -d: -f3)
        local usuario="$1"

        sudo userdel -r "$usuario"
        echo "Usuario $usuario ($nombre $apellido) eliminado correctamente"
        
    else
        echo "Error: el usuario no existe"
    fi
}

usuario_existe() {
        local usuario
        usuario="$(echo "$1" | cut -d: -f3)"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #habra que escapar el $
        grep -q "^${usuario}:" /etc/passwd
}