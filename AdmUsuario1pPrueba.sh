#! /bin/bash

#archivo para ir haciendo pruebas de a poco

#SI NO SE INGRESAN PARAMETROS######################################################################################
if (($# == 0))
then
#para 0 parametros
echo "sin parametros"
#aca se escribe lo que se hace (asi para todos)

elif (($# == 1))
#SI SE INGRESA UN PARAMETRO######################################################################################
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

    fi