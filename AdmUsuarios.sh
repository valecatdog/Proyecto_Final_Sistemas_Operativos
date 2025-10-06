#! /bin/bash

if (($# == 0))
#para 0 parametros
then
echo "sin parametros"
#aca se escribe lo que se hace (asi para todos)


elif (($# == 1))
#para un parametro (yo)
#CHECHEAR QUE HAYA CERRADO LAS ESCRUCTURAS, QUE ESTE LA LOGICA BIEN ESCRITA, QUE ANDE
then
    valido=false
    #variable para el untill
    ruta="$1"
    #guardo en la variable ruta el valor del primer parametro ingresado
    #le puse comillas porque el valor de la variable puede contener espacios (no deberia) o caracteres especiales (*$?etc). Lo preciso para poder 
    #trabajar con la variable aunque hagan eso que dije
   
    #me parece medio redundnte poner = true, pero cgpt me dice qe si no no anda
    until [ $valido = true ]
    #empezando con el valor de la variable en falso, hace lo siguiente hasta que valido sea true
    do
        if [ -f "$ruta" ]
        #velifica que "ruta" sea ruta valida (existente)
        #PODRIA VERIFICAR SI LA ESTRUCTURA ES VALIDA TAMMBIEN
        then
            #si es valido
            echo "archivo valido"
            valido=true
            #para el until
        else
            #si no es valido
            echo "Error: archivo invalido"
            read -p "Ingrese una ruta válida: " ruta
        fi
    done
    echo "-------------------------------------"
    #fin del until

    
    listaUsuarios=()
    #creo un array con todos los usuarios con los que se va a estar trabajando
    for ((i = 1 ; i < $(wc -w < "$ruta") ; i+=2))
    do
    : 'i va a ir tomando el valor de cada nombre en el archivo para hacer los nombres (se explica mejor mas adelante). Empieza en 1.
    Incrementa de 2 en 2 (porque por cada vuelta se usan 2 campos: nombre y apellido). Se ejecuta hasta que i sea mayor a la cantidad de
    campos en el archivo. para eso se cuentan la cantidad de palabras en la ruta. Se escribe wc -w < "$ruta" porque de otra forma, el comando
    wc -w "$ruta" devolveria tambien la ruta junto con la cantidad de palabras, lo cual no sirve en este caso'
        nombreUsuario=$(cut -f$i -c1 "$ruta")$(cut -f$((i+1)) "$ruta")
        #toma el primer caracter del campo que corresponda al valor de i en el archivo y lo une con todo el segundo campo
        listaUsuarios+=$nombreUsuario
        #lo añade al array de usuarios

        # si sobra un nombre (queda fuera de los pares que se van formando), simplemente no se usa

        #HAY QEU CHECHEAR QUE EL ARCHIVO CONTENGA POR LO MENOS UN NOMBRE Y UN APELLIDO EN LA PARTE DE ARRIBA, CUANDO VEO SI EL ARHIVO ES VALIDO
    done

    valido=false
    while [ "$valido" = false ]
    do
        #CAPAZ QUE HABRIA UQE HACER ALGO PARA RETROCEDER? 0?
        echo "Que desea hacer?"
        echo "1. Añadir un usuario al sistema"
        echo "2. Eliminar uno de los usuarios"
        echo "-------------------------------------"
        read -p "Opcion: " op

        case $op in
            1)
                valido=true
                echo "Elegido: 1. Añadir un usuario al sistema"
                if [ ${#listaUsuarios[*]} > 1 ]
                then
                    echo "Con cuál usuario desea trabajar?:"
                    echo "0. Retroceder"
                    for((i = 0 ; i <= ${#listaUsuarios[*]} ; i++))
                    do
                        echo "$i. listaUsuarios[((i+1))]"
                    done
                    opValida=false

                    while ("$opValida" = false)
                    do
                        read -p "Opcion: " opcion
                        if ($opcion > -1 && $opcion <= ${#listaUsuarios[*]})
                        then
                            opValida=true
                            #NOMBRE DE LA FUNCION QUE HACE USUARIOS. TIENE QUE RECIBIR UN PARAMETRO: NOMBRE DE USUARIO
                        else
                        echo "Opcion inválida. Vuelva a intentarlo"
                        fi
                    done
                else
                    echo "si no me da error"
                    #MANDA DIRECTO EL USUARIO A LA FUNCION
                fi

            #esto para aca, no se repite ni nada

            ;;
            2) 
                valido=true
                echo "Elegido: 2. Eliminar uno de los usuarios"
                if [ ${#listaUsuarios[*]} > 1 ]
                then
                    echo "Con cuál usuario desea trabajar?:"
                    echo "0. Retroceder"
                    for((i = 0 ; i <= ${#listaUsuarios[*]} ; i++))
                    do
                        echo "$i. listaUsuarios[((i+1))]"
                    done
                    opValida=false
                    while ("$opValida" = false)
                    do
                        read -p "Opcion: " opcion
                        if ($opcion > -1 && $opcion <= ${#listaUsuarios[*]})
                        then
                            opValida=true
                            #NOMBRE DE LA FUNCION QUE HACE USUARIOS. TIENE QUE RECIBIR UN PARAMETRO: NOMBRE DE 
                            #PARA FUTURO SE PODRIAN METER VARIOS USUARIOS
                        else
                        echo "No se ingresó una opcion valida, vuelva a intentarlo: "
                        fi
                    done
                else
                    #MANDA DIRECTO EL USUARIO A LA FUNCION
                fi
            ;;
            *)
                echo "Asegurese de elegir un valor válido"
            ;;
        esac
    done


#FIN DE SI SE INGRESO UN PARAMETRO
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


