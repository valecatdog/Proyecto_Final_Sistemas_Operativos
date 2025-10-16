#! /bin/bash
#combino las 2 funciones y pruebo si andan
#PROBLEMAS!!!
: '
-no tenemos nombre y apellido
'

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
