#! /bin/bash

if (($# == 0))
#para 0 parametros
then
#aca se escribe lo que se hace (asi para todos)


elif (($# == 1))
#para un parametro (yo)
then


elif (($# == 2))
nombre=$1
apellido=$2

# funcion para generar nombres
generar_username() {
        local nombre="$1"
        local apellido="$2"
        local primera_letra=$(echo "$nombre" | cut -c1) # agarra la primera letra del nombre de nuestro usuario 
        local usuario="${primera_letra}${apellido}" #se guarda el nombre y el apellido de usuario en una variable usuario
        echo "$usuario" | tr "A-Z" "a-z"
}
# compara en passwd para ver si hay un usuario con la misma inicial + apellido
usuario_existe() {
        local usuario="$1" # $1 es el primer parámetro DE LA FUNCIÓN
        # -q = quiet (no imprime mada) # ^ inicio de linea 
        grep -q "^${usuario}:" /etc/passwd
}

echo "1 - Añadir usuario"
echo "2 - Borrar usuario"
read -p "Elige una opción: " opcion

if (( "$opcion" = 1 ))
then

usuario=$(generar_username "$nombre" "$apellido")
    echo "Nombre de usuario generado: $usuario"

        if usuario_existe "$usuario"; then
            echo "Ya hay un usuario registrado con ese username: $usuario"
        else

        # añade el usuario como nuevo system user junto con su directorio de usuario 
        # -c para comment, para poder dividir nombre y apellido en diferentes campos (para luego compararlos con lo del nombre + apellido)
            sudo useradd -m -c "$nombre $apellido" "$usuario"
            echo "usuario '$usuario' creado correctamente"
        fi

elif (( "$opcion" = 2 ))
then
#para borrar el usuario 
if usuario_existe "$usuario"; then
            sudo userdel -r "$usuario"
            echo "Usuario '$usuario' eliminado correctamente"
        else
            echo "El usuario '$usuario' no existe"
        fi
fi


else
    echo "Se ha ingresado una cantidad invalida de parametros"
fi