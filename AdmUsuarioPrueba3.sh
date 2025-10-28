#!/bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
modo sin parametros
actualmente estoy trabajando en gestion de usuarios, crear usuarios, crear usuarios por consola

HACER:
-que ande la lista de usuarios
-qeu se pueda crear grupos
-que se pueda borrar grupos
-que se vea la lista de grupos
-que se puedan añadir y dacar usuarios de grupos

y ta eso es todo lo qeu queda. despues se le pueden agregar mas cosas para hacerlo mas robusto
se le podria agregar la opcion de ponerle contraseña a un gruó


ayuda no me da la cabeza para mas
'

add_usuario1(){

    #creamos las variables y las hacemos locales (solo existen para esta funcion y se resetean cada vez que actua)
    local user
    local nombre
    local apellido
    local letraNombre
    local letraApellido
    local passwd

    # extraemos los datos del usuario (almacenados como nombre:apellido:usuario)
    nombre="$(echo "$1" | cut -d: -f1)"
    apellido="$(echo "$1" | cut -d: -f2)"
    user="$(echo "$1" | cut -d: -f3)"

    #verifico la salida de la funcion, si es distinta a 0 (no se encontró en /etc/passwd asi que no existe) actua
    #le pasamos el primer parametro que se le paso a la funcion actual
    if ! usuario_existe "$1" #probar cambiar esto
    then
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
        ingreso_usuario "$nombre" "$apellido"
        return
        #mensaje para informar que el usuario se creo exitosamente
    else
        read -n1 -t3 -rsp "Error: el usuario $user ($nombre $apellido) ya existe en el sistema"
        : 'informa que el usuario ya existe, no se puede crear
        -n1: acepta un caracter. sirve para que la proxima vez qeu se haga un read, lo que se escribe en este no
        "contamine" el otro (limpia el buffer). -t1: tiempo de espera de un segundo, -r: no interpreta lo que
        escribe el usuario. -s: no muestra lo que se escribe. -p: para mosrtar el mensaje. Como no nos interesa
        si el usuario escribe algo no especificamos una variable para que se guarde
        '
        echo "$1" >> cre_usuarios.log 
        ingreso_usuario "$nombre" "$apellido"
        return
        #pasamos la informacion del usuario (prierm parametro de la funcion) al log 
    fi
} 

add_usuario(){
    echo "=== DEBUG add_usuario ==="
    echo "DEBUG: Parámetro recibido: '$1'"
    
    local user
    local nombre
    local apellido
    
    nombre="$(echo "$1" | cut -d: -f1)"
    apellido="$(echo "$1" | cut -d: -f2)"
    user="$(echo "$1" | cut -d: -f3)"
    
    echo "DEBUG: nombre='$nombre', apellido='$apellido', user='$user'"
    
    if ! usuario_existe "$1"; then
        echo "DEBUG: usuario_existe devolvió FALSE - procediendo a crear usuario"
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
        #ingreso_usuario "$nombre" "$apellido"
        #return
        #mensaje para informar que el usuario se creo exitosamente
    else
        echo "DEBUG: usuario_existe devolvió TRUE - usuario ya existe"
        read -n1 -t3 -rsp "Error: el usuario $user ($nombre $apellido) ya existe en el sistema"
        : 'informa que el usuario ya existe, no se puede crear
        -n1: acepta un caracter. sirve para que la proxima vez qeu se haga un read, lo que se escribe en este no
        "contamine" el otro (limpia el buffer). -t1: tiempo de espera de un segundo, -r: no interpreta lo que
        escribe el usuario. -s: no muestra lo que se escribe. -p: para mosrtar el mensaje. Como no nos interesa
        si el usuario escribe algo no especificamos una variable para que se guarde
        '
        echo "$1" >> cre_usuarios.log 
        #ingreso_usuario "$nombre" "$apellido"
       # return
    fi
    echo "=== FIN DEBUG add_usuario ==="
}

usuario_existe() {
    local user
    user="$(echo "$1" | cut -d: -f3)"
    
    echo "DEBUG usuario_existe: Verificando usuario '$user'"
    
    if getent passwd "$user" >/dev/null ; then
        echo "DEBUG usuario_existe: getent encontró al usuario '$user' - return 0"
        return 0
    else 
        echo "DEBUG usuario_existe: getent NO encontró al usuario '$user' - return 1"
        return 1
    fi
}


#-------------------------------------------

add_usuario "vale:correa:vcorrea"
add_usuario "aru:sifilis:asifilis"
add_usuario "ayuda:help:odiotodioyatodeldo"
add_usuario "vale:correa:vcorrea"
add_usuario "caca:caca:recaca"
add_usuario "qwerty:tasloco:qtasloco"