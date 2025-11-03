#!/bin/bash
# Script de actualización para backup.sh
# Uso: ./update-backup.sh

set -e  # Detener ejecución si hay algún error

echo "=== ACTUALIZADOR DE BACKUP.SH ==="
echo

# Verificar que estamos en el directorio correcto
if [ ! -f "backup.sh" ]; then
    echo "❌ Error: No se encuentra backup.sh en el directorio actual"
    echo "   Asegúrate de ejecutar este script en el mismo directorio que backup.sh"
    exit 1
fi

# Verificar que tenemos permisos de root
if [ "$(whoami)" != "root" ]; then
    echo "❌ Error: Este script debe ejecutarse como root"
    echo "   Uso: sudo ./update-backup.sh"
    exit 1
fi

echo "📋 Estado actual:"
echo "   - backup.sh existe ($(ls -la backup.sh | awk '{print $5}') bytes)"
echo "   - Última modificación: $(ls -la backup.sh | awk '{print $6, $7, $8}')"
echo

# Confirmar con el usuario
read -p "¿Continuar con la actualización? (s/n): " confirmacion
if [ "$confirmacion" != "s" ] && [ "$confirmacion" != "S" ]; then
    echo "❌ Actualización cancelada"
    exit 0
fi

echo
echo "🔄 Iniciando actualización..."

# 1. Hacer backup del script actual (por si acaso)
if [ -f "backup.sh" ]; then
    backup_name="backup.sh"
    cp backup.sh "$backup_name"
    echo "✅ Backup creado: $backup_name"
fi

# 2. Eliminar el script actual
echo "🗑️  Eliminando backup.sh actual..."
rm -f backup.sh
echo "✅ backup.sh eliminado"

# 3. Hacer git pull
echo "📥 Actualizando desde el repositorio..."
if git pull; then
    echo "✅ Git pull completado"
else
    echo "❌ Error en git pull"
    echo "   Por favor, verifica tu conexión y el repositorio"
    exit 1
fi

# 4. Verificar que el nuevo backup.sh existe
if [ ! -f "backup.sh" ]; then
    echo "❌ Error: No se encontró backup.sh después del git pull"
    echo "   Verifica que el repositorio tenga el archivo backup.sh"
    exit 1
fi

# 5. Aplicar permisos
echo "🔒 Aplicando permisos..."
chmod 700 backup.sh
echo "✅ Permisos aplicados: chmod 700 backup.sh"

# 6. Verificación final
echo
echo "✅ Actualización completada exitosamente!"
echo
echo "📊 Estado final:"
echo "   - backup.sh: $(ls -la backup.sh | awk '{print $1, $5}') bytes"
echo "   - Última modificación: $(ls -la backup.sh | awk '{print $6, $7, $8}')"
echo

# Veri ficar que el script es ejecutable
if [ -x "backup.sh" ]; then
    echo "🎯 El script es ejecutable"
else
    echo "⚠️  Advertencia: El script podría no ser ejecutable"
    echo "   Ejecuta manualmente: chmod +x backup.sh"
fi

echo
echo "💡 Puedes probar el nuevo script con:"
echo "   sudo ./backup.sh"