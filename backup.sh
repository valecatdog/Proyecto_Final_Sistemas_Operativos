#!/bin/bash
# Backup manager condensado (misma funcionalidad, sin emojis)

CONFIG_FILE="/etc/backup-script/backup-config.conf"
CRON_HORA="3"
CRON_MINUTO="10"
RSYNC_DELAY_MINUTOS="5"
REMOTE_BACKUP_ENABLED="true"
REMOTE_BACKUP_USER="respaldo_user"
REMOTE_BACKUP_HOST="192.168.0.93"
REMOTE_BACKUP_DIR="/backups/usuarios"
SSH_KEY="/root/.ssh/backup_key"

dir_backup="/var/users_backups"
Delta=$(realpath "$0")
backup_list="/etc/backup-script/auto-backup-list.conf"
LOG="/var/log/backups.log"

# --- Helpers básicos ---
check_user(){ [ "$(whoami)" = "root" ] || { echo "ERROR: ejecutar como root"; exit 1; }; }

cargar_configuracion(){
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "$(date): Configuración cargada desde $CONFIG_FILE" >> "$LOG"
  else
    guardar_configuracion
  fi
}

guardar_configuracion(){
  mkdir -p "/etc/backup-script"
  cat > "$CONFIG_FILE" <<EOF
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
  echo "$(date): Configuración guardada en $CONFIG_FILE" >> "$LOG"
}

actualizar_configuracion(){ eval "$1=\"$2\""; guardar_configuracion; }

formato_am_pm(){
  local h=$1
  [ "$h" -eq 0 ] && echo "12 AM" && return
  [ "$h" -eq 12 ] && echo "12 PM" && return
  [ "$h" -lt 12 ] && echo "${h} AM" && return
  echo "$((h-12)) PM"
}
get_cron_hora_completa(){
  printf "%02d:%02d (%s)\n" "$CRON_HORA" "$CRON_MINUTO" "$(formato_am_pm $CRON_HORA)"
}

# --- Dependencias y conectividad ---
verificar_dependencias(){
  local err=0
  echo "$(date): Verificando dependencias..." >> "$LOG"
  systemctl is-active --quiet atd || { echo "$(date): SERVICIO atd no activo" >> "$LOG"; err=$((err+1)); }
  if [ ! -f "$SSH_KEY" ]; then
    echo "$(date): CLAVE SSH faltante: $SSH_KEY" >> "$LOG"; err=$((err+1))
  else
    [ "$(stat -c %a "$SSH_KEY" 2>/dev/null)" = "600" ] || { chmod 600 "$SSH_KEY"; echo "$(date): Permisos SSH corregidos" >> "$LOG"; }
  fi
  if [ "$REMOTE_BACKUP_ENABLED" = "true" ]; then
    ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo OK" &>/dev/null \
      || { echo "$(date): No se puede conectar a $REMOTE_BACKUP_HOST" >> "$LOG"; err=$((err+1)); }
  fi
  [ -x "$Delta" ] || { chmod +x "$Delta"; echo "$(date): Permisos de script corregidos" >> "$LOG"; }
  if [ -z "$CRON_HORA" ] || [ -z "$CRON_MINUTO" ]; then echo "$(date): CRON_HORA/CRON_MINUTO no configuradas" >> "$LOG"; err=$((err+1)); fi
  [ $err -eq 0 ] && echo "$(date): Dependencias OK" >> "$LOG" || echo "$(date): Se encontraron $err error(es) en dependencias" >> "$LOG"
  return $err
}

# --- Respaldo remoto (rsync) y programación con at ---
realizar_respaldo_remoto(){
  local archivo="$1"; local nombre=$(basename "$archivo")
  [ "$REMOTE_BACKUP_ENABLED" = "true" ] || return 0
  [ -f "$archivo" ] || { echo "$(date): ERROR: $archivo no existe" >> "$LOG"; return 1; }
  [ -f "$SSH_KEY" ] || { echo "$(date): ERROR: $SSH_KEY no existe" >> "$LOG"; return 1; }
  if rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" "$archivo" "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST:$REMOTE_BACKUP_DIR/" >> "$LOG" 2>&1; then
    echo "$(date): Respaldo remoto exitoso: $nombre" >> "$LOG"; return 0
  else
    echo "$(date): ERROR en respaldo remoto: $nombre" >> "$LOG"; return 1
  fi
}

programar_transferencia_remota(){
  local archivo="$1"; local delay="${2:-$RSYNC_DELAY_MINUTOS}"
  [ "$REMOTE_BACKUP_ENABLED" = "true" ] || return 0
  [ -f "$archivo" ] || { echo "$(date): ERROR: archivo para transferir no existe: $archivo" >> "$LOG"; return 1; }
  systemctl is-active --quiet atd || { echo "$(date): ERROR: atd no activo" >> "$LOG"; return 1; }
  [ -f "$SSH_KEY" ] || { echo "$(date): ERROR: clave SSH faltante" >> "$LOG"; return 1; }
  [ "$(stat -c %a "$SSH_KEY" 2>/dev/null)" = "600" ] || chmod 600 "$SSH_KEY"

  local tmp=$(mktemp /tmp/rsync_backup_XXXXXX.sh)
  cat > "$tmp" <<EOT
#!/bin/bash
LOG_FILE="$LOG"
BACKUP_FILE="$archivo"
REMOTE_USER="$REMOTE_BACKUP_USER"
REMOTE_HOST="$REMOTE_BACKUP_HOST"
REMOTE_DIR="$REMOTE_BACKUP_DIR"
SSH_KEY="$SSH_KEY"
echo "\$(date): Iniciando transferencia programada: \$(basename "\$BACKUP_FILE")" >> "\$LOG_FILE"
[ -f "\$BACKUP_FILE" ] || { echo "\$(date): ERROR: archivo desaparecio" >> "\$LOG_FILE"; rm -f "$tmp"; exit 1; }
ssh -i "\$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "\$REMOTE_USER@\${REMOTE_HOST}" "echo conectado" &>/dev/null || { echo "\$(date): ERROR: sin conectividad" >> "\$LOG_FILE"; rm -f "$tmp"; exit 1; }
rsync -avz -e "ssh -i \$SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" "\$BACKUP_FILE" "\$REMOTE_USER@\${REMOTE_HOST}:\$REMOTE_DIR/" >> "\$LOG_FILE" 2>&1 || echo "\$(date): ERROR en rsync" >> "\$LOG_FILE"
rm -f "$tmp"
EOT
  chmod +x "$tmp"
  if echo "$tmp" | at "now + $delay minutes" 2>/dev/null; then
    echo "$(date): Transferencia programada para $(basename "$archivo")" >> "$LOG"
    return 0
  else
    echo "$(date): ERROR: no se pudo programar at" >> "$LOG"
    rm -f "$tmp"
    return 1
  fi
}

probar_conexion_remota(){
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$REMOTE_BACKUP_USER@$REMOTE_BACKUP_HOST" "echo 'Conexión exitosa'" &>/dev/null \
    && echo "Conexión remota funcionando" || echo "Error en conexión remota"
}

# --- Preparación de directorios y archivos ---
crear_dir_backup(){
  mkdir -p "$dir_backup" && chmod 700 "$dir_backup"
  [ -f "$LOG" ] || { touch "$LOG"; chmod 644 "$LOG"; }
  mkdir -p /etc/backup-script && chmod 700 /etc/backup-script
  if [ ! -f "$backup_list" ]; then
    cat > "$backup_list" <<EOF
# Lista de usuarios y grupos para backup automatico
# Formato: usuario o @grupo
EOF
    chmod 600 "$backup_list"
  fi
}

backup_automatico_activo(){
  crontab -l 2>/dev/null | grep -q "$Delta"
}

# --- Utilidades de usuario/grupo ---
usuario_existe(){ id "$1" &>/dev/null; }
grupo_existe(){ getent group "$1" &>/dev/null; }
obtener_usuarios_de_grupo(){ getent group "$1" | cut -d: -f4 | tr ',' '\n'; }
leer_con_cancelar(){
  local prompt="$1"
  local var="$2"
  echo -n "$prompt (o 0 para cancelar): "
  read -r "$var"
  if [ "${!var}" = "0" ]; then
    echo "Operación cancelada."
    return 1
  fi
  return 0
}
# --- Gestión de lista automática ---
ver_lista_backup_auto(){
  echo "=== LISTA DE BACKUPS ==="
  if [ ! -s "$backup_list" ]; then
    echo "La lista está vacía."
  else
    grep -v '^#' "$backup_list" | grep -v '^$' | nl -w2 -s'. '
  fi
}

add_usuario_backup_auto(){
  local usuario
  leer_con_cancelar "Ingrese usuario" usuario || return 1
  if usuario_existe "$usuario"; then
    grep -q "^$usuario$" "$backup_list" || echo "$usuario" >> "$backup_list" && echo "Usuario $usuario añadido."
  else
    echo "Usuario $usuario no existe."
  fi
}

add_grupo_backup_auto(){
  local grupo
  leer_con_cancelar "Ingrese grupo" grupo || return 1
  if grupo_existe "$grupo"; then
    local gline="@$grupo"
    grep -q "^$gline$" "$backup_list" || echo "$gline" >> "$backup_list" && echo "Grupo $grupo añadido."
  else
    echo "Grupo $grupo no existe."
  fi
}

eliminar_elemento_backup_auto(){
  ver_lista_backup_auto
  [ -s "$backup_list" ] || return 1
  local numero
  leer_con_cancelar "Ingrese número a eliminar" numero || return 1
  local elemento=$(grep -v '^#' "$backup_list" | grep -v '^$' | sed -n "${numero}p")
  [ -z "$elemento" ] && { echo "Número inválido"; return 1; }
  echo -n "Confirmar eliminar '$elemento' (s/n): "; read c
  [ "$c" = "s" ] && grep -v "^$elemento$" "$backup_list" > "$(mktemp)" && mv "$(mktemp)" "$backup_list" && echo "Eliminado." || echo "Cancelado."
}

gestionar_backup_auto(){
  while true; do
    echo "1) Ver 2) Añadir usuario 3) Añadir grupo 4) Eliminar 0) Volver"
    read op
    case $op in
      1) ver_lista_backup_auto;;
      2) add_usuario_backup_auto;;
      3) add_grupo_backup_auto;;
      4) eliminar_elemento_backup_auto;;
      0) return 0;;
      *) echo "Opción inválida";;
    esac
    echo "Presione Enter para continuar..."; read
  done
}

# --- Creación de backups ---
crear_backup_grupo(){
  local grupo
  leer_con_cancelar "Ingrese nombre del grupo" grupo || return 1
  grupo_existe "$grupo" || { echo "Grupo no existe."; return 1; }
  local fecha=$(date '+%Y%m%d_%H%M%S')
  local temp_counter=$(mktemp)
  echo 0 > "$temp_counter"
  while IFS= read -r usuario; do
    [ -z "$usuario" ] && continue
    usuario_existe "$usuario" || { echo "Usuario $usuario no existe, omitiendo"; continue; }
    local home_dir=$(getent passwd "$usuario" | cut -d: -f6)
    [ -d "$home_dir" ] || { echo "Home no existe: $home_dir"; continue; }
    local archivo="${dir_backup}/backup_${usuario}_grupo_${fecha}.tar.bz2"
    if tar -cjf "$archivo" "$home_dir" 2>/dev/null; then
      echo "$(date): Backup creado: $archivo" >> "$LOG"
      local c=$(cat "$temp_counter"); echo $((c+1)) > "$temp_counter"
      programar_transferencia_remota "$archivo"
    else
      echo "Error creando backup de $usuario"
    fi
  done < <(obtener_usuarios_de_grupo "$grupo")
  local processed=$(cat "$temp_counter"); rm -f "$temp_counter"
  echo "Backup de grupo completado: $processed usuarios procesados"
}

crear_backup(){
  while true; do
    echo "1) Usuario 2) Grupo 0) Volver"; read tipo
    case $tipo in
      1)
        local usuario
        leer_con_cancelar "Ingrese usuario" usuario || break
        usuario_existe "$usuario" || { echo "Usuario no existe"; break; }
        local home_dir=$(getent passwd "$usuario" | cut -d: -f6)
        local fecha=$(date '+%Y%m%d_%H%M%S')
        local archivo="${dir_backup}/backup_${usuario}_${fecha}.tar.bz2"
        if tar -cjf "$archivo" "$home_dir" 2>/dev/null; then
          echo "$(date): Backup manual de $usuario - $archivo" >> "$LOG"
          programar_transferencia_remota "$archivo"
        else
          echo "Error creando backup"
        fi
        break
        ;;
      2) crear_backup_grupo; break ;;
      0) return 1 ;;
      *) echo "Opción inválida" ;;
    esac
  done
}

# --- Backup diario (lee backup_list) ---
backup_diario(){
  local fecha=$(date '+%Y%m%d_%H%M%S')
  local usuarios_procesados=0 archivos_creados=() exit_code=0
  echo "$(date): [BACKUP-DIARIO] Iniciando" >> "$LOG"
  [ -n "$CRON_HORA" ] && [ -n "$CRON_MINUTO" ] || { echo "$(date): CRON no configurado" >> "$LOG"; return 1; }
  [ -f "$backup_list" ] || { echo "$(date): Lista no encontrada: $backup_list" >> "$LOG"; return 1; }
  if [ ! -s "$backup_list" ]; then echo "$(date): Lista vacía" >> "$LOG"; return 0; fi

  while IFS= read -r linea; do
    [[ -z "$linea" || "$linea" =~ ^# ]] && continue
    if [[ "$linea" =~ ^@ ]]; then
      grupo="${linea#@}"
      if grupo_existe "$grupo"; then
        while IFS= read -r usuario; do
          [ -z "$usuario" ] && continue
          usuario_existe "$usuario" || { echo "$(date): Usuario $usuario no existe" >> "$LOG"; exit_code=1; continue; }
          local home_dir=$(getent passwd "$usuario" | cut -d: -f6)
          [ -d "$home_dir" ] || { echo "$(date): Home no existe: $home_dir" >> "$LOG"; continue; }
          local archivo="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
          if tar -cjf "$archivo" -C / "$home_dir" >> "$LOG" 2>&1; then
            ((usuarios_procesados++)); archivos_creados+=("$archivo")
            [ "$REMOTE_BACKUP_ENABLED" = "true" ] && programar_transferencia_remota "$archivo" "$RSYNC_DELAY_MINUTOS"
          else
            echo "$(date): ERROR creando backup para $usuario" >> "$LOG"; exit_code=1
          fi
        done < <(obtener_usuarios_de_grupo "$grupo")
      else
        echo "$(date): Grupo no existe: $grupo" >> "$LOG"; exit_code=1
      fi
    else
      usuario="$linea"
      usuario_existe "$usuario" || { echo "$(date): Usuario no existe: $usuario" >> "$LOG"; exit_code=1; continue; }
      home_dir=$(getent passwd "$usuario" | cut -d: -f6)
      [ -d "$home_dir" ] || { echo "$(date): Home no existe: $home_dir" >> "$LOG"; continue; }
      archivo="${dir_backup}/diario_${usuario}_${fecha}.tar.bz2"
      if tar -cjf "$archivo" -C / "$home_dir" "$home_dir" >> "$LOG" 2>&1; then
        ((usuarios_procesados++)); archivos_creados+=("$archivo")
        [ "$REMOTE_BACKUP_ENABLED" = "true" ] && programar_transferencia_remota "$archivo" "$RSYNC_DELAY_MINUTOS"
      else
        echo "$(date): ERROR creando backup para $usuario" >> "$LOG"; exit_code=1
      fi
    fi
  done < "$backup_list"

  echo "$(date): [BACKUP-DIARIO] Completado: $usuarios_procesados usuarios" >> "$LOG"
  return $exit_code
}

# --- Activar/Desactivar backup automático (crontab) ---
toggle_backup_automatico(){
  if backup_automatico_activo; then
    (crontab -l 2>/dev/null | grep -v "$Delta") | crontab -
    echo "$(date): Backup automático DESACTIVADO" >> "$LOG"
  else
    echo "$(date): Verificando dependencias..." >> "$LOG"
    ! verificar_dependencias && { echo "No se puede activar; revisa $LOG"; return 1; }
    if ! grep -v '^#' "$backup_list" | grep -v '^$' | grep -q .; then
      echo "ADVERTENCIA: lista de backups vacía."
    fi
    local entrada_cron="$CRON_MINUTO $CRON_HORA * * * $Delta automatico"
    (crontab -l 2>/dev/null; echo "$entrada_cron") | crontab -
    echo "$(date): Backup automático ACTIVADO - $entrada_cron" >> "$LOG"
    crontab -l | grep "$Delta"
  fi
}

# --- Restauración ---
restaurar_backup(){
  while true; do
    ls -1 "$dir_backup"/*.tar.bz2 2>/dev/null | nl -w2 -s'. '
    [ $? -ne 0 ] && { echo "No hay backups disponibles."; read; return 1; }
    echo -n "Seleccione número (0 volver): "; read numero
    [ "$numero" = "0" ] && return 1
    archivo_backup=$(ls -1 "$dir_backup"/*.tar.bz2 | sed -n "${numero}p")
    [ -z "$archivo_backup" ] && { echo "Número inválido"; continue; }
    nombre_archivo=$(basename "$archivo_backup")
    if [[ "$nombre_archivo" =~ ^backup_([^_]+)_ ]]; then usuario="${BASH_REMATCH[1]}"; else echo "Formato no reconocido"; continue; fi
    usuario_existe "$usuario" || { echo "ERROR: usuario $usuario no existe"; read; continue; }
    home_destino=$(getent passwd "$usuario" | cut -d: -f6)
    echo "Restaurar backup de $usuario en $home_destino. ADVERTENCIA: sobrescribe. Continuar (s/n/0)?: "; read confirm
    [ "$confirm" = "0" ] && continue
    [ "$confirm" != "s" ] && { echo "Cancelado"; continue; }
    temp_dir=$(mktemp -d)
    if tar -xjf "$archivo_backup" -C "$temp_dir" 2>/dev/null; then
      if [ -d "$temp_dir/home/$usuario" ]; then dir_origen="$temp_dir/home/$usuario"
      elif [ -d "$temp_dir/$usuario" ]; then dir_origen="$temp_dir/$usuario"
      else dir_origen="$temp_dir/$usuario"; fi
      rsync -av "$dir_origen/" "$home_destino"/ 2>/dev/null
      chown -R "$usuario:$usuario" "$home_destino"
      echo "Restauración completada"
      rm -rf "$temp_dir"
    else
      echo "ERROR: No se pudo extraer el backup"; rm -rf "$temp_dir"
    fi
    read -p "Presione Enter para continuar..."
    break
  done
}

# --- Inicialización y menú ---
cargar_configuracion
check_user
crear_dir_backup

if [ "$1" = "automatico" ]; then
  {
    echo "================================================"
    echo "$(date): INICIANDO BACKUP AUTOMÁTICO DIARIO"
    echo "================================================"
    [ -f "$backup_list" ] || { echo "ERROR: no existe $backup_list"; exit 1; }
    [ -s "$backup_list" ] || { echo "INFO: lista vacía"; exit 0; }
    if backup_diario; then echo "Backup automático completado"; else echo "Backup automático falló"; fi
    echo "================================================"
    echo "$(date): FINALIZANDO BACKUP AUTOMÁTICO DIARIO"
    echo "================================================"
  } >> "$LOG" 2>&1
  exit 0
fi

while true; do
  clear
  echo "=== GESTOR DE BACKUPS ==="
  echo "1) Crear backup manual"
  backup_automatico_activo && echo "2) DESACTIVAR backup diario automático [ACTIVO]" || echo "2) ACTIVAR backup diario automático [INACTIVO]"
  echo "3) Restaurar backup"
  echo "4) Gestionar lista de backups automáticos"
  echo "5) Configurar respaldo remoto"
  echo "6) Probar backup automático (ejecuta ahora)"
  echo "7) Verificar dependencias"
  echo "0) Salir"
  echo -n "Seleccione opción: "; read opcion
  case $opcion in
    1) crear_backup ;;
    2) toggle_backup_automatico ;;
    3) restaurar_backup ;;
    4) gestionar_backup_auto ;;
    5) configurar_respaldo_remoto ;;
    6) echo "Ejecutando backup automático de prueba..."; backup_diario ;;
    7) verificar_dependencias; echo "Verificación completada. Revisa $LOG" ;;
    0) echo "Cerrando..."; exit 0 ;;
    *) echo "Opción inválida" ;;
  esac
  echo "Presione Enter para continuar..."; read
done
