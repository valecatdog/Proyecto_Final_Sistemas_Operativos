#!/bin/bash
#espacio 2 para probar casos individuales
#TRABAJANDO EN:
: '
verificando todo 1x1 poruqe no se

'
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
    usuario="${nombre}:${apellido}:$user"
    #usamos el formato nombre:apellido:user porque es lo mas comodo para trababarlo en el resto del script
}

usuario_existe() {
        local user
        user="$(echo "$1" | cut -d: -f3)"
        echo "esto es usuario $usuario"
        echo "eso es user $user"
        getent passwd "$user" > /dev/null
}

add_usuario(){

    #verifico la salida de la funcion, si es distinta a 0 (no se encontró en /etc/passwd asi que no existe) actua
    #le pasamos el primer parametro que se le paso a la funcion actual
    if ! usuario_existe "$1"
    then
        #creamos las variables y las hacemos locales (solo existen para esta funcion)
        local usuario
        local nombre
        local apellido
        local letraNombre
        local letraApellido
        local passwd

        # extraemos los datos del usuario (almacenados como nombre:apellido:usuario)
        nombre="$(echo "$1" | cut -d: -f1)"
        apellido="$(echo "$1" | cut -d: -f2)"
        usuario="$(echo "$1" | cut -d: -f3)"

        #generar contraseña
        letraNombre=$(echo "$nombre" | cut -c1 | tr '[:lower:]' '[:upper:]')
        #extraemos la primera letra del nombre (como antes) y si esta en minuscula la pasamos a mayuscula
        letraApellido=$(echo "$apellido" | cut -c1 | tr '[:upper:]' '[:lower:]')
        #extraemos la primera letra del apellido (como antes) y si esta en mayuscula la pasamos a minuscula
        passwd="$letraNombre${letraApellido}#123456"
        #la contraseña va a se la letraNombre+letraApellido+#123456 (como pide la consigna)

        #ingresar usuario
        sudo useradd -mc "$nombre $apellido" "$usuario"
        : 'aniadimos el usuario con useradd. -m crea el directorio del usuario si no existe y
        -c agrema un comentario (nombre apellido). aunque el script deberia ser ejecutado con sudo, en caso
        de olvido, lo agregamos de todas formas 
        '
        echo "$usuario":"$passwd" | sudo chpasswd 
        #chpasswd, que asigna contrasenias, espera recibir parametros por entrada estandar. por eso el pipe
        sudo chage -d 0 "$usuario"
        #chage -d establece a fecha del ultimo cambio de la contrasenia, y 0 hace qeu expire inmediatamente

        read -n1 -t2 -rsp "Usuario $usuario creado correctamente. Contraseña: $passwd"
        ingreso_usuario "$nombre" "$apellido"
        return
        #mensaje para informar que el usuario se creo exitosamente
        
    else
        read -n1 -t1 -rsp "Error: el usuario $usuario ($nombre $apellido) ya existe en el sistema"
        : 'informa que el usuario ya existe, no se puede crear
        -n1: acepta un caracter. sirve para que la proxima vez qeu se haga un read, lo que se escribe en este no
        "contamine" el otro (limpia el buffer). -t1: tiempo de espera de un segundo, -r: no interpreta lo que
        escribe el usuario. -s: no muestra lo que se escribe. -p: para mosrtar el mensaje. Como no nos interesa
        si el usuario escribe algo no especificamos una variable para que se guarde
        '
        echo "$1" >> cre_usuarios.log 
        #ingreso_usuario "$nombre" "$apellido"
        return
        #pasamos la informacion del usuario (prierm parametro de la funcion) al log 
    fi
} 

#FIN FUNCIONES"#######################################################3
clear
read -rp "ingresa nombre y apellido: " nombre apellido
generar_usuario "$nombre" "$apellido"
add_usuario "$usuario"


