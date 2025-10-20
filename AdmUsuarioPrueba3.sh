#! /bin/bash
#espacio 2 para probar casos individuales
#TRABAJANDO EN:
: '
- hacer que la funcion generar username ande
'
#escrctura del usuario:
#nombre:apellido:usuario

generar_data() {
    local nombre
    local apellido
    local usuario
    local primeraLetra
    #se hace por separado porque al ponerle local de una se pierde el valor de retorno ($?, si es 0, 1 etc)

    nombre="$1"
    apellido="$2"
    primeraLetra=$(echo "$nombre" | cut -c1)
    usuario="$primeraLetra$apellido"
    primeraLetra="$(echo "$1" | cut -c1)"
    data="${nombre}:${apellido}:$usuario"
}

read -rp "1er nombre y apellido: " nombres
nombre=$(echo "$nombres" | cut -d" " -f1)
apellido=$(echo "$nombres" | cut -d" " -f12)
generar_data "$nombre" "$apellido"
echo "los datos son: $data"

read -rp "2do nombre y apellido: " nombres
nombre=$(echo "$nombres" | cut -d" " -f1)
apellido=$(echo "$nombres" | cut -d" " -f12)
generar_data "$nombre" "$apellido"
echo "los datos son: $data"

read -rp "3er nombre y apellido: " nombres
nombre=$(echo "$nombres" | cut -d" " -f1)
apellido=$(echo "$nombres" | cut -d" " -f12)
generar_data "$nombre" "$apellido"
echo "los datos son: $data"
