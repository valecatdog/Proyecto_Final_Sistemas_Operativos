#!/bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
probar una cosita
'

mapfile -t listaGrupos < <(getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
echo "${listaGrupos[@]}"
mapfile listaGrupos < <(getent group | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
echo "${listaGrupos[@]}"
