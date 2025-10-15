#! /bin/bash
#ARCHIVO PARA PRUEBAS DEL SCRIPT COMPLETO

#SI NO SE INGRESAN PARAMETROS######################################################################################
if (($# == 0))
then
echo "sin parametros"
#todavia no hay nada


#SI SE INGRESA UN PARAMETRO######################################################################################
elif (($# == 1))
then
    valido=false
    #variable para el untill
    archivo="$1"
    #guardo en la variable archivo  el valor del primer parametro ingresado (su ruta)
    : 'le puse comillas porque el valor de la variable puede contener espacios (no deberia) o caracteres especiales (*$?etc). Lo preciso para poder 
    #trabajar con la variable aunque hagan eso que dije'
   
    #verifica que se haya pasado un archivo valido. En otro caso, te sigue preguntando hasta que se lo ingreses
    #ALGO PARA ROMPER EL BUCLE SI TE ARREPENTISTE!!!

    #empezando con el valor de la variable en falso, hace lo siguiente hasta que valido sea true
    until [ $valido ]
    do
        if [ -f "$archivo" ]
        #velifica que "archivo" sea un archivo valido (existente)
        #PODRIA VERIFICAR SI LA ESTRUCTURA ES VALIDA TAMMBIEN!!!
        then
            #si es valido
            echo "Archivo encontrado."
    
            #le pongo comillas por las dudas de que me de mas de una palabra (no deberia). Es una buena practica.
            if [ "$(wc -w < archivo.txt)" -lt 2 ]
            then
                echo "Error: archivo invalido. Los archivos tienen que tener por lo menos dos palabras (nombre y apellido)"
                read -p "Ingrese una ruta válida: " archivo
                valido=true
                #detiene el until
            else
                echo "Archivo valido"
            fi
        else
            #si no es valido
            echo "Error: archivo invalido o no encontrado"
            read -p "Ingrese una ruta válida: " archivo
        fi
    done
    echo "-------------------------------------"
    #fin del until

fi

##############################################ESTA PARTE ESTA CORRECTA############################################

    listaUsuarios=()
    #creo un array con todos los usuarios con los que se va a estar trabajando
    for ((i = 1 ; i < $(wc -w < "$archivo") ; i+=2))
    do

    : 'i va a ir tomando el valor de cada nombre en el archivo para hacer los nombres (se explica mejor mas adelante). Empieza en 1.
    Incrementa de 2 en 2 (porque por cada vuelta se usan 2 campos: nombre y apellido). Se ejecuta hasta que i sea mayor a la cantidad de
    campos en el archivo. para eso se cuentan la cantidad de palabras en la ruta. Se escribe wc -w < "$archivo" porque de otra forma, el comando
    wc -w "$archivo" devolveria tambien la ruta junto con la cantidad de palabras, lo cual no sirve en este caso'

        nombreUsuario=$(cut -f$i -c1 "$archivo")$(cut -f$((i+1)) "$archivo")
        #toma el primer caracter del campo que corresponda al valor de i en el archivo y lo une con todo el segundo campo
        listaUsuarios+=("$nombreUsuario")
        #lo añade al array de usuarios

        # si sobra un nombre (queda fuera de los pares que se van formando), simplemente no se usa

        #HAY QEU CHECHEAR QUE EL ARCHIVO CONTENGA POR LO MENOS UN NOMBRE Y UN APELLIDO EN LA PARTE DE ARRIBA, CUANDO VEO SI EL ARHIVO ES VALIDO
    done




#esto es el final del if principal
