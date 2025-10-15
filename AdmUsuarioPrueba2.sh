#! /bin/bash
generar_username() {
    local nombreCompleto="$1$2"
    local nombreUsuario=$(cat nombreCompleto |cut -c1)$(cat nombreCompleto | cut -d" "-f2)
    cat nombreUsuario
}

#importante que la funcion este arriba, tiene que estar definida poruqe bash va linea por linea, no loee todo y dsp hace
#como es en otros lenguajes
generar_username "nahiara" "sosa"

#y para guardar el nombre de usuario
nombreUsuario=$(generar_username "sophia castro")

cat nombreUsuario


