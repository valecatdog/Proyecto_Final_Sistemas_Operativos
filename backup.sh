#!/bin/bash

# Archivo de configuración persistente
CONFIG_FILE="/etc/backup-script/backup-config.conf"

# Configuración por defecto
CRON_HORA="3"
CRON_MINUTO="10"
RSYNC_DELAY_MINUTOS="5"
REMOTE_BACKUP_ENABLED="true"
REMOTE_BACKUP_USER="respaldo_user"
REMOTE_BACKUP_HOST="192.168.0.93"
REMOTE_BACKUP_DIR="/backups/usuarios"
SSH_KEY="/root/.ssh/backup_key"

# Variables del sistema
dir_backup="/var/users_backups"
Delta=$(realpath "$0")
backup_list="/etc/backup-script/auto-backup-list.conf"

# Cargar configuración persistente
cargar_configuracion

# Funciones básicas del sistema
check_user() {
    [ "$(whoami)" = "root" ] || { echo "ERROR: Ejecutar con sudo o como root"; echo "Uso: sudo $0"; exit 1; }
}

cargar_configuracion() {
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" || guardar_configuracion
}

guardar_configuracion() {
    mkdir -p "/etc/backup-script"
    cat > "$CONFIG_FILE" << EOF
CRON_HORA="$CRON_HORA"
CRON_MINUTO="$CRON_MINUTO"
RSYNC_DELAY_MINUTOS="$RSYNC_DELAY_MINUTOS"
REMOTE_BACKUP_ENABLED="$REMOTE_BACKUP_ENABLED"
REMOTE_BACKUP_USER="$REMOTE_BACKUP_USER"
REMOTE_BACKUP_HOST="$REMOTE_BACKUP_HOST"
REMOTE_BACKUP_DIR="$REMOTE_BACKUP_DIR"
SSH_KEY="$SSH_KEY"
EOF
    chmod 600 "$CONFIG_FILE"
}

actualizar_configuracion() {
    eval "$1=\"$2\""
    guardar_configuracion
}

# Funciones de utilidad
get_cron_hora_completa() {
    local hora=$CRON_HORA
    local minuto=$(printf "%02d" "$CRON_MINUTO")
    local am_pm="AM"
    [ "$hora" -ge 12 ] && am_pm="PM"
    [ "$hora" -gt 12 ] && hora=$((hora - 12))
    [ "$hora" -eq 0 ] && hora=12
    echo "${CRON_HORA}:${minuto} (${hora} ${am_pm})"
}

usuario_existe() { 
    id "$1" &>/dev/null
}

grupo_existe() {
    getent group "$1" &>/dev/null
}

obtener_usuarios_de_grupo() {
    getent group "$1" | cut -d: -f4 | tr ',' '\n'
}

leer_con_cancelar() {
    echo -n "$1 (o '0' para cancelar): "
    read $2
    [ "${!2}" = "0" ] && { echo "Operación cancelada."; return 1; }
    return 0
}

backup_automatico_activo() {
    crontab -l 2>/dev/null | grep -q "$Delta"
}

# Funciones de backup
crear_dir_backup() {
    [ ! -d "$dir_backup" ] && mkdir -p "$dir_backup" && chmod 700 "$dir_backup"
    [ ! -f "/var/log/backups.log" ] && touch "/var/log/backups.log" && chmod 644 "/var/log/backups.log"
    [ ! -d "/etc/backup-script" ] && mkdir -p "/etc/backup-script" && chmod 700 "/etc/backup-script"
    [ ! -f "$backup_list" ] && {
        touch "$backup_list"
        chmod 600 "$backup_list"
        echo -e "# Lista de usuarios y grupos para backup automatico\n# Formato: usuario o @grupo" > "$backup_list"
    }
}

programar_transferencia_remota() {
    [ "$REMOTE_BACKUP_ENABLED" != "true" ] && return 0
    [ ! -f "$1" ] && { echo "ERROR: Archivo no encontrado: $1" >> /var/log/backups.log; return 1; }
    
    local temp_script=$(mktemp /tmp/rsync_backup_XXXXXX.sh)
    cat > "$temp_script" << SCRIPT_EOF
#!/bin/bash
if [ ! -f "$1" ]; then
    echo "\$(date): ERROR: Archivo local desapareció: $(basename "$1")" >> /var/log/backups.log
    rm -f "$temp_script"
    exit 1
fi
if /usr/bin/rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" "$1" "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST:$REMOTE_BACKUP_DIR/" >> /var/log/backups.log 2>&1; then
    echo "\$(date): TRANSFERENCIA EXITOSA: $(basename "$1")" >> /var/log/backups.log
else
    echo "\$(date): ERROR en transferencia: $(basename "$1")" >> /var/log/backups.log
fi
rm -f "$temp_script"
SCRIPT_EOF
    
    chmod +x "$temp_script"
    echo "$temp_script" | at "now + ${2:-$RSYNC_DELAY_MINUTOS} minutes" 2>/dev/null && return 0
    rm -f "$temp_script"
    return 1
}

crear_backup_usuario() {
    local usuario=$1
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local home_dir=$(getent passwd "$usuario" | cut -d: -f6)
    local archivo_backup="${dir_backup}/backup_${usuario}_${fecha}.tar.bz2"
    
    echo "Creando backup de $home_dir"
    if tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null; then
        echo "Backup creado: $archivo_backup"
        echo "$(date): Backup manual de $usuario - $archivo_backup" >> /var/log/backups.log
        programar_transferencia_remota "$archivo_backup"
    else
        echo "Error al crear el backup"
    fi
}

crear_backup_grupo() {
    local grupo=$1
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local usuarios_procesados=0
    
    echo "Creando backup del grupo: $grupo"
    while IFS= read -r usuario; do
        [ -n "$usuario" ] && usuario_existe "$usuario" && {
            home_dir=$(getent passwd "$usuario" | cut -d: -f6)
            [ -d "$home_dir" ] && {
                archivo_backup="${dir_backup}/backup_${usuario}_grupo_${fecha}.tar.bz2"
                tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null && {
                    echo "Backup creado: $(basename "$archivo_backup")"
                    echo "$(date): Backup manual de grupo $grupo - usuario $usuario" >> /var/log/backups.log
                    programar_transferencia_remota "$archivo_backup"
                    ((usuarios_procesados++))
                }
            }
        }
    done < <(obtener_usuarios_de_grupo "$grupo")
    
    echo "Backup de grupo completado: $usuarios_procesados usuarios procesados"
}

crear_backup() {
    while true; do
        echo "¿Qué tipo de backup desea crear?"
        echo "1. Backup de usuario individual"
        echo "2. Backup de grupo"
        echo "0. Volver al menú principal"
        read -p "Seleccione opción: " tipo_backup

        case $tipo_backup in
            1)
                leer_con_cancelar "Ingrese nombre de usuario" usuario && 
                usuario_existe "$usuario" && crear_backup_usuario "$usuario"
                break
                ;;
            2)
                leer_con_cancelar "Ingrese nombre del grupo" grupo && 
                grupo_existe "$grupo" && crear_backup_grupo "$grupo"
                break
                ;;
            0) return 1 ;;
            *) echo "Opción inválida" ;;
        esac
    done
}

backup_diario() {
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local usuarios_procesados=0
    
    echo "$(date): [BACKUP-DIARIO] Iniciando backup automático" >> /var/log/backups.log

    [ ! -s "$backup_list" ] && {
        echo "$(date): [BACKUP-DIARIO] Lista vacía" >> /var/log/backups.log
        return 0
    }

    while IFS= read -r linea; do
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue
        
        if [[ "$linea" =~ ^@ ]]; then
            grupo="${linea#@}"
            grupo_existe "$grupo" && {
                while IFS= read -r usuario; do
                    [ -n "$usuario" ] && usuario_existe "$usuario" && {
                        home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                        [ -d "$home_dir" ] && {
                            archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                            tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null && {
                                echo "$(date): [BACKUP-DIARIO] Backup creado: $usuario" >> /var/log/backups.log
                                [ "$REMOTE_BACKUP_ENABLED" = "true" ] && programar_transferencia_remota "$archivo_backup"
                                ((usuarios_procesados++))
                            }
                        }
                    }
                done < <(obtener_usuarios_de_grupo "$grupo")
            }
        else
            usuario="$linea"
            usuario_existe "$usuario" && {
                home_dir=$(getent passwd "$usuario" | cut -d: -f6)
                [ -d "$home_dir" ] && {
                    archivo_backup="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
                    tar -cjf "$archivo_backup" -C / "$home_dir" 2>/dev/null && {
                        echo "$(date): [BACKUP-DIARIO] Backup creado: $usuario" >> /var/log/backups.log
                        [ "$REMOTE_BACKUP_ENABLED" = "true" ] && programar_transferencia_remota "$archivo_backup"
                        ((usuarios_procesados++))
                    }
                }
            }
        fi
    done < "$backup_list"

    echo "$(date): [BACKUP-DIARIO] Completado: $usuarios_procesados usuarios" >> /var/log/backups.log
}

# Gestión de backups automáticos
ver_lista_backup_auto() {
    echo "=== LISTA ACTUAL DE BACKUPS AUTOMÁTICOS ==="
    [ ! -s "$backup_list" ] && echo "La lista está vacía." || 
    grep -v '^#' "$backup_list" | grep -v '^$' | nl -w 2 -s '. '
}

añadir_usuario_backup_auto() {
    leer_con_cancelar "Ingrese nombre de usuario a añadir" usuario && 
    usuario_existe "$usuario" && {
        grep -q "^$usuario$" "$backup_list" || echo "$usuario" >> "$backup_list"
    }
}

añadir_grupo_backup_auto() {
    leer_con_cancelar "Ingrese nombre del grupo a añadir" grupo && 
    grupo_existe "$grupo" && {
        grupo_line="@$grupo"
        grep -q "^$grupo_line$" "$backup_list" || echo "$grupo_line" >> "$backup_list"
    }
}

eliminar_elemento_backup_auto() {
    ver_lista_backup_auto
    [ ! -s "$backup_list" ] && return 1
    
    leer_con_cancelar "Ingrese el número del elemento a eliminar" numero && {
        elemento=$(grep -v '^#' "$backup_list" | grep -v '^$' | sed -n "${numero}p")
        [ -n "$elemento" ] && {
            echo "¿Eliminar '$elemento' de la lista?"
            read -p "Confirmar (s/n): " confirmacion
            [ "$confirmacion" = "s" ] && {
                grep -v "^$elemento$" "$backup_list" > /tmp/backup_list.tmp
                mv /tmp/backup_list.tmp "$backup_list"
                echo "Elemento '$elemento' eliminado."
            }
        }
    }
}

gestionar_backup_auto() {
    while true; do
        echo "=== GESTIÓN DE BACKUPS AUTOMÁTICOS ==="
        echo "1. Ver lista actual"
        echo "2. Añadir usuario a la lista"
        echo "3. Añadir grupo a la lista"
        echo "4. Eliminar elemento de la lista"
        echo "0. Volver al menú principal"
        echo
        read -p "Seleccione opción: " opcion
        
        case $opcion in
            1) ver_lista_backup_auto ;;
            2) añadir_usuario_backup_auto ;;
            3) añadir_grupo_backup_auto ;;
            4) eliminar_elemento_backup_auto ;;
            0) return 0 ;;
            *) echo "Opción inválida" ;;
        esac
        echo && read -p "Presione Enter para continuar..."
    done
}

# Restauración de backups
restaurar_backup() {
    while true; do
        echo "Backups disponibles:"
        ls -1 "$dir_backup"/*.tar.bz1 2>/dev/null | nl -w 2 -s '. ' || {
            echo "No hay backups disponibles."
            read -p "Presione Enter para continuar..."
            return 1
        }

        read -p "Seleccione el numero del backup a restaurar (0 para volver): " numero
        [ "$numero" = "0" ] && return 1
        
        archivo_backup=$(ls -1 "$dir_backup"/*.tar.bz2 | sed -n "${numero}p")
        [ -z "$archivo_backup" ] && { echo "Numero invalido"; continue; }
        
        nombre_archivo=$(basename "$archivo_backup")
        [[ "$nombre_archivo" =~ ^backup_([^_]+)_ ]] && usuario="${BASH_REMATCH[1]}"
        
        [ -z "$usuario" ] && { echo "Formato de archivo no reconocido"; continue; }
        usuario_existe "$usuario" || { echo "Usuario $usuario no existe"; continue; }
        
        home_destino=$(getent passwd "$usuario" | cut -d':' -f6)
        echo "¿Restaurar backup de $usuario en $home_destino?"
        read -p "Confirmar (s/n): " confirmacion
        [ "$confirmacion" != "s" ] && continue
        
        temp_dir=$(mktemp -d)
        tar -xjf "$archivo_backup" -C "$temp_dir" 2>/dev/null && {
            if [ -d "$temp_dir/home/$usuario" ]; then
                dir_origen="$temp_dir/home/$usuario"
            elif [ -d "$temp_dir/$usuario" ]; then
                dir_origen="$temp_dir/$usuario"
            else
                dir_origen="$temp_dir"
            fi
            
            rsync -av "$dir_origen/" "$home_destino"/ 2>/dev/null
            chown -R "$usuario:$usuario" "$home_destino"
            echo "Restauración completada"
            rm -rf "$temp_dir"
        } || echo "ERROR: No se pudo extraer el backup"
        
        read -p "Presione Enter para continuar..."
        break
    done
}

# Configuración remota
probar_conexion_remota() {
    ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo 'Conexión exitosa'" 2>/dev/null && 
    echo "Conexión remota funcionando" || echo "Error en conexión remota"
}

configurar_respaldo_remoto() {
    while true; do
        echo "=== CONFIGURACIÓN DE RESPALDO REMOTO ==="
        echo "1. $( [ "$REMOTE_BACKUP_ENABLED" = "true" ] && echo "DESACTIVAR" || echo "ACTIVAR" ) respaldo remoto"
        echo "2. Probar conexión remota"
        echo "3. Ver configuración actual"
        echo "4. Configurar delay de transferencia (actual: $RSYNC_DELAY_MINUTOS min)"
        echo "5. Configurar hora del backup (actual: $(get_cron_hora_completa))"
        echo "0. Volver al menú principal"
        echo
        read -p "Seleccione opción: " opcion
        
        case $opcion in
            1)
                [ "$REMOTE_BACKUP_ENABLED" = "true" ] && 
                actualizar_configuracion "REMOTE_BACKUP_ENABLED" "false" ||
                actualizar_configuracion "REMOTE_BACKUP_ENABLED" "true"
                ;;
            2) probar_conexion_remota ;;
            3)
                echo "Usuario: $REMOTE_BACKUP_USER"
                echo "Host: $REMOTE_BACKUP_HOST"
                echo "Directorio: $REMOTE_BACKUP_DIR"
                echo "Habilitado: $REMOTE_BACKUP_ENABLED"
                echo "Delay: $RSYNC_DELAY_MINUTOS minutos"
                echo "Hora backup: $(get_cron_hora_completa)"
                ;;
            4)
                read -p "Nuevo delay en minutos: " nuevo_delay
                [[ "$nuevo_delay" =~ ^[0-9]+$ ]] && [ "$nuevo_delay" -gt 0 ] &&
                actualizar_configuracion "RSYNC_DELAY_MINUTOS" "$nuevo_delay"
                ;;
            5)
                read -p "Nueva hora (0-23): " nueva_hora
                [[ "$nueva_hora" =~ ^[0-9]+$ ]] && [ "$nueva_hora" -ge 0 ] && [ "$nueva_hora" -le 23 ] &&
                actualizar_configuracion "CRON_HORA" "$nueva_hora"
                
                read -p "Nuevo minuto (0-59): " nuevo_minuto
                [[ "$nuevo_minuto" =~ ^[0-9]+$ ]] && [ "$nuevo_minuto" -ge 0 ] && [ "$nuevo_minuto" -le 59 ] &&
                actualizar_configuracion "CRON_MINUTO" "$nuevo_minuto"
                
                backup_automatico_activo && {
                    echo "Actualizando programación en cron..."
                    toggle_backup_automatico
                    toggle_backup_automatico
                }
                ;;
            0) return 0 ;;
            *) echo "Opción inválida" ;;
        esac
        echo && read -p "Presione Enter para continuar..."
    done
}

# Gestión de cron
toggle_backup_automatico() {
    if backup_automatico_activo; then
        (crontab -l 2>/dev/null | grep -v "$Delta") | crontab -
        echo "Backup automático DESACTIVADO"
    else
        [ ! -s "$backup_list" ] && echo "ADVERTENCIA: Lista de backups vacía"
        local entrada_cron="$CRON_MINUTO $CRON_HORA * * * $Delta automatico"
        (crontab -l 2>/dev/null; echo "$entrada_cron") | crontab -
        echo "Backup automático ACTIVADO - $(get_cron_hora_completa)"
    fi
}

# Menú principal
menu_principal() {
    echo "=== GESTOR DE BACKUPS ==="
    echo "1. Crear backup manual"
    echo "2. $(backup_automatico_activo && echo "DESACTIVAR" || echo "ACTIVAR") backup diario automático"
    echo "3. Restaurar backup"
    echo "4. Gestionar lista de backups automáticos"
    echo "5. Configurar respaldo remoto"
    echo "6. Probar backup automático (ejecuta ahora)"
    echo "0. Salir"
    echo
    read -p "Seleccione opción: " opcion
}

# Punto de entrada principal
check_user
crear_dir_backup

if [ "$1" = "automatico" ]; then
    echo "$(date): INICIANDO BACKUP AUTOMÁTICO" >> /var/log/backups.log
    [ -s "$backup_list" ] && backup_diario
    echo "$(date): FINALIZANDO BACKUP AUTOMÁTICO" >> /var/log/backups.log
    exit 0
fi

while true; do
    menu_principal
    case $opcion in
        1) crear_backup ;;
        2) toggle_backup_automatico ;;
        3) restaurar_backup ;;
        4) gestionar_backup_auto ;;
        5) configurar_respaldo_remoto ;;
        6) backup_diario ;;
        0) echo "Cerrando programa"; exit 0 ;;
        *) echo "Opción inválida" ;;
    esac
    echo && read -p "Presione Enter para continuar..."
done