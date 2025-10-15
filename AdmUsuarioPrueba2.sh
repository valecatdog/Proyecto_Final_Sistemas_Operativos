#! /bin/bash
generar_username() {
    local nombreCompleto="$1$2"
    local nombreUsuario=$(cut -c1 "$nombreCompleto")$(cut -d" "-f2 "$nombreCompleto")
    cat nombreUsuario
}

#importante que la funcion este arriba, tiene que estar definida poruqe bash va linea por linea, no loee todo y dsp hace
#como es en otros lenguajes
generar_username "nahiara" "sosa"

#y para guardar el nombre de usuario
nombreUsuario=$(generar_username "sophia castro")

cat nombreUsuario


