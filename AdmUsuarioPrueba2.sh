#! /bin/bash
#combino las 2 funciones y pruebo si andan
#PROBLEMAS!!!
archivo=UsuariosParaAniadir.txt


 listaUsuarios=()
    #creo un array para todos los usuarios con los que se va a estar trabajando

    #recorro todos los elementod del archivo con un for
    for ((i = 1 ; i < $(wc -w < "$archivo") ; i+=2))
    do
        nombre="$(cat "$archivo" | cut -d" " -f$i)"
        apellido="$(cat "$archivo" | cut -d" " -f$((i+1)))"
        nombreUsuario="$(echo "$nombre" | cut -c1)$apellido"
        listaUsuarios+=("$nombreUsuario":"$nombre":"$apellido")
        
        echo "nombre usuario: $nombreUsuario, nombre: $nombre, apellido: $apellido"
        #lo añade al array de usuarios

        # si sobra un nombre (queda fuera de los pares que se van formando), simplemente no se usa
    done



: '-no tenemos nombre y apellido


add_usuario(){
    local nombre=
    local apellido=
    local usuario="$1"
    letraNombre=$(echo "$usuario" | tr "[:lower:]" "[:upper]")
    letraApellido=$(echo "$usuario" |tr "[:upper]" "[:lower:]")
    passwd="$($letraNombre$letraApellido#1234)"
    sudo useradd -mc "$nombre $apellido" "$usuario"
    #aca hay qeu ver como sacar el apellido para poder hacer el comentario
    echo "Usuario '$usuario' creado correctamente"
    chpasswd $usuario:$passwd
    #chatgpt lo hace mas raro, no se si esto estara andando
} 

usuario_existe() {
        local usuario="$1"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #diferencia entre {} y ()
        #habra que escapar el $
        grep -q "^${usuario}:" /etc/passwd
}

echo "Arranca la prueba--------------------------------------------"
'