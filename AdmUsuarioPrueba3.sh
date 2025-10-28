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