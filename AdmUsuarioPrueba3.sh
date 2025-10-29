#!/bin/bash
#espacio para probar casos individuales
#TRABAJANDO EN:
: '
probar una cosita
'

if sudo groupdel esteseborra; then
    echo "se borro"
else
    echo "no se borro"
fi
