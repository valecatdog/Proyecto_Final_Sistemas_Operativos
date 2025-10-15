#! /bin/bash
generar_username() {
    local nombreCompleto="$1$2"
    local nombreUsuario=$(cat "$nombreCompleto" |cut -c1)$(cat "$nombreCompleto" | cut -d" "-f2)
    echo "$nombreUsuario"
}

#importante que la funcion este arriba, tiene que estar definida poruqe bash va linea por linea, no loee todo y dsp hace
#como es en otros lenguajes
echo "#####################pruebo la funcion con parametros"
generar_username "nahiara" "sosa"

#y para guardar el nombre de usuario
echo "#####################pruebo la funcion guardandola en una variable y haceindole cat"
nombreUsuario=$(generar_username "sophia castro")
cat nombreUsuario


