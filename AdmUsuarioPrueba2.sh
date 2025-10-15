#! /bin/bash
generar_username() {
    local primeraLetra="$(echo "$1" | cut -c1)"
    local nombreUsuario=$primeraLetra$2
    echo "$nombreUsuario"
}

#importante que la funcion este arriba, tiene que estar definida poruqe bash va linea por linea, no loee todo y dsp hace
#como es en otros lenguajes
echo "#####################pruebo la funcion con parametros"
generar_username "nahiara" "sosa"

#y para guardar el nombre de usuario
echo "#####################pruebo la funcion guardandola en una variable y haceindole cat"
nombreUsuario=$(generar_username "sophia" "castro")
cat "$nombreUsuario"


