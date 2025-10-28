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
        local usuario
        usuario="$(echo "$1" | cut -d: -f3)"
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        #habra que escapar el $
        getent passwd "$usuario" >/dev/null
        : 'verifica si existe el usuario en passwd, si existe te imprime su info. como no qeuremos eso, lo redirigimos 
        a /dev/null'
}

#FIN FUNCIONES"#######################################################3

read -r "ingresa nombre y apellido: " nombre apellido
generar_usuario "$nombre" "$apellido"
echo "$usuario"
if ! usuario_existe "$usuario"
then
    echo "el usuario no existe"
else 
    echo "el usuario no existe"
fi



