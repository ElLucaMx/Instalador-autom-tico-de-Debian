#!/bin/bash
# =========
# Información
# =========

# GitHub: https://github.com/ElLucaMx?tab=repositories
# Creador: ElLucaMx
# Fecha de creación: 26/10/2026
# Última modificación:
# Web: (Próximamente)

# ============================================================
# Zona de variables
# ============================================================

# Directorio donde se encuentra este script.
DIRECTORIO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Repositorio oficial de imágenes Debian.
URL_ISO="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd"

# Variables de descarga.
ISO_LOCAL=""
ISO_NOMBRE=""
VERSION_LOCAL=""
VERSION_ULTIMA=""
ISO_DESCARGA_TEMPORAL=""

# Variables de personalización.
DIRECTORIO_TEMPORAL=""
ARCHIVO_MD5_ORIGINAL=""
ARCHIVO_MD5_NUEVO=""
ISO_TEMPORAL=""
NOMBRE_ISO_AUTO=""
ISO_PERSONALIZADA=""
INFO_ARRANQUE=""

# ============================================================
# Zona de funciones
# ============================================================

# ============================================================
# Comprobación de dependencias
# ============================================================

f_comprobar_dependencias() {

    local dependencias=(
        curl
        grep
        awk
        sed
        sort
        tail
        sha512sum
        basename
        dirname
        mv
        rm
        chmod
        mkdir
        cat
        date
        xorriso
        md5sum
        mktemp
        cmp
        cut
    )

    local dependencia

    echo "Comprobando dependencias..."

    for dependencia in "${dependencias[@]}"; do

        if ! command -v "$dependencia" >/dev/null 2>&1; then
            echo "Error: falta la dependencia $dependencia."
            return 1
        fi

    done

    echo "Dependencias disponibles."
}

# ============================================================
# Búsqueda de ISO local
# ============================================================

f_buscar_iso() {

    local archivos=()

    ISO_LOCAL=""
    ISO_NOMBRE=""

    shopt -s nullglob
    archivos=("$DIRECTORIO"/debian-*-amd64-netinst.iso)
    shopt -u nullglob

    if [ "${#archivos[@]}" -eq 0 ]; then
        echo "No se ha encontrado ninguna ISO Debian."
        return 1
    fi

    if [ "${#archivos[@]}" -gt 1 ]; then
        echo "Error: se han encontrado varias ISO Debian."
        printf '  %s\n' "${archivos[@]}"
        return 2
    fi

    ISO_LOCAL="${archivos[0]}"
    ISO_NOMBRE="$(basename "$ISO_LOCAL")"

    echo "ISO encontrada: $ISO_NOMBRE"
}

# ============================================================
# Detección de la última versión disponible
# ============================================================

f_obtener_ultima_version() {

    local listado
    local versiones

    echo "Consultando las versiones disponibles..."

    listado=$(curl -fsSL "$URL_ISO/") || {
        echo "Error: no se ha podido consultar Debian."
        return 1
    }

    versiones=$(printf '%s\n' "$listado" |
        grep -oE 'debian-[0-9]+\.[0-9]+\.[0-9]+-amd64-netinst\.iso' |
        sed -E 's/^debian-([0-9]+\.[0-9]+\.[0-9]+)-amd64-netinst\.iso$/\1/' |
        sort -Vu)

    if [ -z "$versiones" ]; then
        echo "Error: no se ha podido obtener la versión disponible."
        return 1
    fi

    VERSION_ULTIMA="$(printf '%s\n' "$versiones" | tail -n 1)"

    echo "Última versión disponible: $VERSION_ULTIMA"
}

# ============================================================
# Detección de la versión local
# ============================================================

f_obtener_version_local() {

    if [[ "$ISO_NOMBRE" =~ ^debian-([0-9]+\.[0-9]+\.[0-9]+)-amd64-netinst\.iso$ ]]; then
        VERSION_LOCAL="${BASH_REMATCH[1]}"
    else
        echo "Error: el nombre de la ISO no tiene un formato reconocido."
        return 1
    fi

    echo "Versión local: $VERSION_LOCAL"
}

# ============================================================
# Verificación de la ISO local
# ============================================================

f_verificar_iso_local() {

    local suma
    local archivo_sumas

    archivo_sumas="$DIRECTORIO/SHA512SUMS.tmp"

    echo "Descargando sumas de comprobación..."

    if ! curl -fsSL "$URL_ISO/SHA512SUMS" -o "$archivo_sumas"; then
        echo "Error: no se han podido descargar las sumas."
        rm -f -- "$archivo_sumas"
        return 1
    fi

    suma=$(awk -v archivo="$ISO_NOMBRE" '$2 == archivo {print $1; exit}' "$archivo_sumas")

    rm -f -- "$archivo_sumas"

    if [ -z "$suma" ]; then
        echo "Error: no se encuentra la suma SHA-512 de la ISO local."
        return 1
    fi

    echo "Verificando integridad de la ISO local..."

    if ! (
        cd "$DIRECTORIO" &&
        printf '%s  %s\n' "$suma" "$ISO_NOMBRE" | sha512sum -c -
    ); then

        echo "Error: la ISO local no supera la verificación."
        return 1
    fi

    echo "La ISO local ha superado la verificación SHA-512."
}

# ============================================================
# Descarga de la ISO
# ============================================================

f_descargar_iso() {

    local nombre
    local suma
    local archivo_sumas
    local destino

    nombre="debian-${VERSION_ULTIMA}-amd64-netinst.iso"
    destino="$DIRECTORIO/$nombre"

    ISO_DESCARGA_TEMPORAL="$destino.part"
    archivo_sumas="$DIRECTORIO/SHA512SUMS.tmp"

    echo "Descargando Debian $VERSION_ULTIMA..."

    if ! curl -fL --retry 3 \
        "$URL_ISO/$nombre" \
        -o "$ISO_DESCARGA_TEMPORAL"; then

        echo "Error: no se ha podido descargar la ISO."
        rm -f -- "$ISO_DESCARGA_TEMPORAL" "$archivo_sumas"
        return 1
    fi

    echo "Descargando sumas de comprobación..."

    if ! curl -fsSL "$URL_ISO/SHA512SUMS" -o "$archivo_sumas"; then
        echo "Error: no se han podido descargar las sumas."
        rm -f -- "$ISO_DESCARGA_TEMPORAL" "$archivo_sumas"
        return 1
    fi

    suma=$(awk -v archivo="$nombre" '$2 == archivo {print $1; exit}' "$archivo_sumas")

    if [ -z "$suma" ]; then
        echo "Error: no se encuentra la suma SHA-512 de la ISO."
        rm -f -- "$ISO_DESCARGA_TEMPORAL" "$archivo_sumas"
        return 1
    fi

    echo "Verificando integridad..."

    if ! printf '%s  %s\n' "$suma" "$ISO_DESCARGA_TEMPORAL" | sha512sum -c -; then
        echo "Error: la ISO descargada no supera la verificación."
        rm -f -- "$ISO_DESCARGA_TEMPORAL" "$archivo_sumas"
        return 1
    fi

    rm -f -- "$archivo_sumas"

    # Colocar la nueva ISO después de verificarla.
    if ! mv -f -- "$ISO_DESCARGA_TEMPORAL" "$destino"; then
        echo "Error: no se ha podido colocar la nueva ISO."
        rm -f -- "$ISO_DESCARGA_TEMPORAL"
        return 1
    fi

    # Eliminar la ISO anterior si tiene un nombre diferente.
    if [ -n "$ISO_LOCAL" ] &&
       [ -f "$ISO_LOCAL" ] &&
       [ "$ISO_LOCAL" != "$destino" ]; then

        if ! rm -f -- "$ISO_LOCAL"; then
            echo "Aviso: no se ha podido eliminar la ISO anterior."
        fi

    fi

    ISO_LOCAL="$destino"
    ISO_NOMBRE="$nombre"

    echo "ISO descargada y verificada correctamente."
}

# ============================================================
# Coordinación de la comprobación de ISO
# ============================================================

f_comprobar_iso() {

    local resultado

    f_obtener_ultima_version || return 1

    f_buscar_iso
    resultado=$?

    case "$resultado" in

        0)

            f_obtener_version_local || return 1

            if [ "$VERSION_LOCAL" = "$VERSION_ULTIMA" ]; then

                echo "La ISO local tiene la última versión disponible."

                if f_verificar_iso_local; then
                    echo "La ISO está actualizada y su integridad es correcta."
                    echo "No es necesario descargar nada."
                    return 0
                fi

                echo "La ISO local no ha superado la verificación."
                echo "Se descargará una copia nueva."

            else

                echo "La ISO local está desactualizada."
                echo "Se descargará la última versión disponible."

            fi

            f_descargar_iso || return 1
            ;;

        1)

            echo "Se descargará la última versión disponible."

            ISO_LOCAL=""

            f_descargar_iso || return 1
            ;;

        2)

            echo "Error: hay varias ISO Debian en el directorio."
            echo "Deja solamente una ISO netinst antes de continuar."

            return 1
            ;;

        *)

            echo "Error: no se ha podido determinar el estado de la ISO."

            return 1
            ;;

    esac
}

# ============================================================
# Generación de archivos
# ============================================================

# ============================================================
# Generar preseed.cfg
# ============================================================

f_generar_preseed() {

    cat > "$DIRECTORIO/preseed.cfg" <<'EOF'
### Localización

d-i debian-installer/locale string es_ES.UTF-8
d-i keyboard-configuration/xkb-keymap select es


### Registro y configuración inicial

# Registrar el comienzo de la instalación.
d-i preseed/early_command string \
    echo "$(date '+%F %T') - Inicio de la instalación automatizada" >> /var/log/instalacion.log; \
    echo "$(date '+%F %T') - La configuración de red se delegará a netcfg" >> /var/log/instalacion.log


### Red

# Seleccionar automáticamente una interfaz de red disponible.
d-i netcfg/choose_interface select auto

# Esperar hasta 10 segundos para detectar el enlace de red.
d-i netcfg/link_wait_timeout string 10

# Esperar hasta 60 segundos para obtener una respuesta DHCP.
d-i netcfg/dhcp_timeout string 60

# Establecer el nombre del equipo.
d-i netcfg/get_hostname string elhuesaso
d-i netcfg/get_domain string unassigned-domain

# Permitir la carga de firmware necesario para el hardware.
d-i hw-detect/load_firmware boolean true


### Repositorios

d-i mirror/country string manual
d-i mirror/http/hostname string ftp.cica.es
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string


### Usuarios

d-i passwd/root-password-crypted password $6$lQ4wnIXhXkzsIxOM$f8MCi7mXs51odJ7zdeNBLFDO3IqLR7LS9/oGL3jOkA3alQHK174d/pk02lR7YBxvXm/MtqDMXj4h0B7RikIVv1

d-i passwd/user-fullname string Usr.Usuario
d-i passwd/username string usuario
d-i passwd/user-password-crypted password $6$vFUIcw7Q7Ex2f5Yj$xP1vTPfzGfO3yLRIRpsi6lelNW5S18nbPtvCY3WSLgYG7sAMuTwCb1FBoUH1xfQ.FXKO1cUXXyJ7R5/GDLMVy/


### Reloj

d-i clock-setup/utc boolean true
d-i time/zone string Europe/Madrid
d-i clock-setup/ntp boolean true


### Particionado

# Se fuerza GPT tanto para UEFI como para BIOS.
# En BIOS, la receta crea una partición BIOS Boot de 2 MiB.
d-i partman-partitioning/choose_label select gpt
d-i partman-partitioning/default_label string gpt

# Usar LVM; el script establecerá disco y receta personalizada.
d-i partman-auto/method string lvm
d-i partman-auto-lvm/new_vg_name string vg0

# Ejecutar el particionador dinámico justo antes de que partman comience.
d-i partman/early_command string \
    echo "$(date '+%F %T') - Iniciando configuración dinámica del particionado" >> /var/log/instalacion.log; \
    /bin/sh /cdrom/particionado.sh || exit 1; \
    echo "$(date '+%F %T') - Receta de particionado preparada" >> /var/log/instalacion.log

# Eliminar configuraciones LVM y RAID anteriores.
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true

# Confirmar automáticamente la escritura de la tabla y LVM.
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true


### APT

d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/non-free-firmware boolean true
d-i apt-setup/non-free boolean true
d-i apt-setup/contrib boolean true
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_host string security.debian.org


### Instalación de paquetes

tasksel tasksel/first multiselect standard, gnome-desktop

d-i pkgsel/include string flatpak gnome-software-plugin-flatpak openssh-server
d-i pkgsel/upgrade select safe-upgrade

popularity-contest popularity-contest/participate boolean false


### GRUB

d-i grub-installer/only_debian boolean true


### Configuración final

# Añadir Flathub para todo el sistema y conservar el registro.
d-i preseed/late_command string \
    echo "$(date '+%F %T') - Particionado completado" >> /var/log/instalacion.log; \
    echo "$(date '+%F %T') - Instalación del sistema base y paquetes completada" >> /var/log/instalacion.log; \
    echo "$(date '+%F %T') - Iniciando configuración de Flathub" >> /var/log/instalacion.log; \
    in-target flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || exit 1; \
    echo "$(date '+%F %T') - Repositorio Flathub configurado" >> /var/log/instalacion.log; \
    mkdir -p /target/var/log/installer || exit 1; \
    cp /var/log/instalacion.log /target/var/log/installer/instalacion.log || exit 1; \
    echo "$(date '+%F %T') - Registro copiado al sistema instalado" >> /target/var/log/installer/instalacion.log


# Evitar la pregunta final antes del reinicio.
d-i finish-install/reboot_in_progress note
EOF

    [ -s "$DIRECTORIO/preseed.cfg" ] || return 1
}

# ============================================================
# Generar particionado.sh
# ============================================================

f_generar_particionado() {

    cat > "$DIRECTORIO/particionado.sh" <<'EOF'
#!/bin/sh

# =========
# Información
# =========

# GitHub: https://github.com/ElLucaMx?tab=repositories
# Creador: ElLucaMx
# Fecha de creación: 26/10/2026
# Última modificación:
# Web: (Próximamente)

# =========
# Zona de variables
# =========

FIRMWARE=""
DISCO=""
RECETA=""

TAMANO_DISCO_MIB=0
TAMANO_ARRANQUE_MIB=0
TAMANO_BOOT_MIB=0
TAMANO_SWAP_MIB=0
TAMANO_RAIZ_MIB=0
TAMANO_HOME_MIB=0

RAM_MIB=0
ESPACIO_LVM_MIB=0
ESPACIO_DESPUES_SWAP_MIB=0
RESERVA_LVM_MIB=64

DISCOS_VALIDOS=""

LOG="/var/log/instalacion.log"

# ============================================================
# ============================================================
# Zona de funciones
# ============================================================
# ============================================================

# ============================================================
# Configuración del registro
# ============================================================

f_configurar_log() {

    mkdir -p "$(dirname "$LOG")" || return 1

    touch "$LOG" || {
        echo "Error: no se puede crear el fichero de log." >&2
        return 1
    }

    exec >> "$LOG" 2>&1

    f_log "===================================================="
    f_log "Registro preparado"
}

# Registrar mensajes con fecha y hora.
f_log() {

    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Registrar errores.
f_error() {

    f_log "ERROR: $*" >&2
}


# ============================================================
# Detección de firmware
# ============================================================
f_detectar_firmware() {
    if [ -d /sys/firmware/efi ]; then
        FIRMWARE="UEFI"
    else
        FIRMWARE="BIOS"
    fi

    f_log "Firmware detectado: $FIRMWARE"
}

# ============================================================
# Seleción de disco
# ============================================================
f_detectar_discos() {
    local lista_dispositivos
    local dispositivo
    local nombre
    local ruta_sys

    DISCOS_VALIDOS=""

    if ! command -v list-devices >/dev/null 2>&1; then
        f_error "no se encuentra list-devices."
        return 1
    fi

    if ! command -v readlink >/dev/null 2>&1; then
        f_error "no se encuentra readlink; no es seguro identificar discos USB."
        return 1
    fi

    lista_dispositivos=$(list-devices disk) || {
        f_error "no se han podido detectar los discos."
        return 1
    }

    if [ -z "$lista_dispositivos" ]; then
        f_error "no se ha encontrado ningún disco."
        return 1
    fi

    for dispositivo in $lista_dispositivos; do
        nombre=${dispositivo##*/}

        if [ ! -e "/sys/block/$nombre/device" ]; then
            echo "Aviso: no se puede identificar $dispositivo. Se omite."
            continue
        fi

        ruta_sys=$(readlink -f "/sys/block/$nombre/device" 2>/dev/null)

        if [ -z "$ruta_sys" ]; then
            echo "Aviso: no se puede resolver la ruta de $dispositivo. Se omite."
            continue
        fi

        # Excluir rutas de sysfs que atraviesen un bus USB.
        case "$ruta_sys" in
            */usb[0-9]*/*)
                echo "Disco USB excluido: $dispositivo"
                continue
                ;;
        esac

        DISCOS_VALIDOS="$DISCOS_VALIDOS $dispositivo"
        echo "Disco válido: $dispositivo"
    done

    if [ -z "$DISCOS_VALIDOS" ]; then
        f_error "no se han encontrado discos válidos después de excluir USB."
        return 1
    fi
}

# Detectar los discos, asignarles prioridad y seleccionar uno.
# Prioridad orientativa: NVMe > SSD/no rotacional > HDD/rotacional.
# No mide velocidades reales de lectura/escritura.
f_asignar_prioridad() {
    f_detectar_discos || return 1

    local dispositivo
    local nombre
    local rotacional
    local prioridad
    local tipo
    local mejor_prioridad
    local mejor_tipo

    mejor_prioridad=-1
    mejor_tipo=""
    DISCO=""

    for dispositivo in $DISCOS_VALIDOS; do
        nombre=${dispositivo##*/}

        case "$nombre" in
            nvme*)
                prioridad=3
                tipo="NVMe"
                ;;
            *)
                rotacional=$(cat "/sys/block/$nombre/queue/rotational" 2>/dev/null)

                case "$rotacional" in
                    0)
                        prioridad=2
                        tipo="SSD/no rotacional"
                        ;;
                    1)
                        prioridad=1
                        tipo="HDD/rotacional"
                        ;;
                    *)
                        prioridad=0
                        tipo="desconocido"
                        ;;
                esac
                ;;
        esac

        echo "Candidato: $dispositivo ($tipo, prioridad $prioridad)"

        if [ "$prioridad" -gt "$mejor_prioridad" ]; then
            DISCO="$dispositivo"
            mejor_prioridad="$prioridad"
            mejor_tipo="$tipo"
        fi
    done

    if [ -z "$DISCO" ]; then
        f_error "no se ha podido seleccionar ningún disco."
        return 1
    fi

    echo "Disco seleccionado: $DISCO ($mejor_tipo)"

    if ! command -v debconf-set >/dev/null 2>&1; then
        f_error "no se encuentra debconf-set."
        return 1
    fi

    debconf-set partman-auto/disk "$DISCO" || return 1
    debconf-set grub-installer/bootdev "$DISCO" || return 1
}


# ============================================================
# Particionado del disco
# ============================================================

# Obtener el tamaño del disco desde sysfs.
# /sys/block/<disco>/size expresa el tamaño en sectores de 512 bytes.
f_detectar_tamano_disco() {
    local nombre
    local sectores

    if [ -z "$DISCO" ]; then
        f_error "no hay ningún disco seleccionado."
        return 1
    fi

    nombre=${DISCO##*/}

    if [ ! -r "/sys/block/$nombre/size" ]; then
        f_error "no se puede leer el tamaño de $DISCO."
        return 1
    fi

    sectores=$(cat "/sys/block/$nombre/size" 2>/dev/null)

    case "$sectores" in
        ''|*[!0-9]*)
            f_error "el tamaño devuelto para $DISCO no es válido."
            return 1
            ;;
    esac

    # 2048 sectores de 512 bytes equivalen a 1 MiB.
    TAMANO_DISCO_MIB=$((sectores / 2048))

    if [ "$TAMANO_DISCO_MIB" -le 0 ]; then
        f_error "el tamaño calculado para $DISCO no es válido."
        return 1
    fi

    echo "Tamaño del disco seleccionado: $TAMANO_DISCO_MIB MiB"
}

# Reservar espacio para EFI o BIOS Boot.
# El preseed fuerza GPT, por lo que BIOS necesita una partición biosgrub.
f_asignar_arranque() {
    case "$FIRMWARE" in
        UEFI)
            TAMANO_ARRANQUE_MIB=512
            ;;
        BIOS)
            TAMANO_ARRANQUE_MIB=2
            ;;
        *)
            f_error "firmware desconocido."
            return 1
            ;;
    esac

    echo "Espacio para arranque: $TAMANO_ARRANQUE_MIB MiB"
}

# Reservar 1 GiB para /boot fuera de LVM.
f_asignar_boot() {
    TAMANO_BOOT_MIB=1024
    echo "Espacio para /boot: $TAMANO_BOOT_MIB MiB"
}

# Reservar la mitad de la RAM para swap, con un máximo de 32 GiB.
f_asignar_swap() {
    if [ ! -r /proc/meminfo ]; then
        f_error "no se puede leer /proc/meminfo."
        return 1
    fi

    RAM_MIB=$(awk '/^MemTotal:/ {printf "%d", $2 / 1024}' /proc/meminfo)

    case "$RAM_MIB" in
        ''|*[!0-9]*)
            f_error "no se ha podido detectar la RAM."
            return 1
            ;;
    esac

    if [ "$RAM_MIB" -le 0 ]; then
        f_error "la cantidad de RAM detectada no es válida."
        return 1
    fi

    TAMANO_SWAP_MIB=$((RAM_MIB / 2))

    if [ "$TAMANO_SWAP_MIB" -gt 32768 ]; then
        TAMANO_SWAP_MIB=32768
    fi

    echo "RAM detectada: $RAM_MIB MiB"
    echo "Espacio para swap: $TAMANO_SWAP_MIB MiB"
}

# Calcular el espacio de LVM y asignar el 55 % restante a raíz.
# Se reservan 64 MiB dentro del VG para metadatos/alineación y margen.
f_asignar_raiz() {
    ESPACIO_LVM_MIB=$((TAMANO_DISCO_MIB - TAMANO_ARRANQUE_MIB - TAMANO_BOOT_MIB))

    if [ "$ESPACIO_LVM_MIB" -le 0 ]; then
        f_error "no queda espacio para LVM."
        return 1
    fi

    ESPACIO_DESPUES_SWAP_MIB=$((ESPACIO_LVM_MIB - RESERVA_LVM_MIB - TAMANO_SWAP_MIB))

    if [ "$ESPACIO_DESPUES_SWAP_MIB" -le 0 ]; then
        f_error "el disco no tiene espacio suficiente para el arranque, swap y reserva LVM."
        return 1
    fi

    TAMANO_RAIZ_MIB=$((ESPACIO_DESPUES_SWAP_MIB * 55 / 100))

    if [ "$TAMANO_RAIZ_MIB" -le 0 ]; then
        f_error "el tamaño calculado para / no es válido."
        return 1
    fi

    echo "Espacio para /: $TAMANO_RAIZ_MIB MiB"
}

# Asignar a /home el espacio restante después de swap, reserva y raíz.
f_asignar_home() {
    TAMANO_HOME_MIB=$((ESPACIO_DESPUES_SWAP_MIB - TAMANO_RAIZ_MIB))

    if [ "$TAMANO_HOME_MIB" -le 0 ]; then
        f_error "el tamaño calculado para /home no es válido."
        return 1
    fi

    echo "Espacio para /home: $TAMANO_HOME_MIB MiB"
}

# ============================================================
# Creación de receta personalizada
# ============================================================
f_generar_receta() {
    local ARCHIVO_RECETA

    ARCHIVO_RECETA="/tmp/receta-particionado"

    if [ "$TAMANO_DISCO_MIB" -le 0 ] ||
       [ "$TAMANO_ARRANQUE_MIB" -le 0 ] ||
       [ "$TAMANO_BOOT_MIB" -le 0 ] ||
       [ "$TAMANO_SWAP_MIB" -le 0 ] ||
       [ "$TAMANO_RAIZ_MIB" -le 0 ] ||
       [ "$TAMANO_HOME_MIB" -le 0 ]; then
        f_error "los tamaños de las particiones no son válidos."
        return 1
    fi

    case "$FIRMWARE" in
        UEFI)
            RECETA="uefi"

            cat > "$ARCHIVO_RECETA" <<EOF_RECIPE
particionado-uefi ::
    ${TAMANO_ARRANQUE_MIB} ${TAMANO_ARRANQUE_MIB} ${TAMANO_ARRANQUE_MIB} free
        \$iflabel{ gpt }
        \$reusemethod{ }
        method{ efi }
        format{ }
    .
    ${TAMANO_BOOT_MIB} ${TAMANO_BOOT_MIB} ${TAMANO_BOOT_MIB} ext4
        \$primary{ }
        method{ format }
        format{ }
        use_filesystem{ }
        filesystem{ ext4 }
        mountpoint{ /boot }
    .
    100 10000 -1 ext4
        \$defaultignore{ }
        \$primary{ }
        method{ lvm }
        device{ ${DISCO} }
        vg_name{ vg0 }
    .
    ${TAMANO_SWAP_MIB} ${TAMANO_SWAP_MIB} ${TAMANO_SWAP_MIB} linux-swap
        \$lvmok{ }
        in_vg{ vg0 }
        lv_name{ swap }
        method{ swap }
        format{ }
    .
    ${TAMANO_RAIZ_MIB} ${TAMANO_RAIZ_MIB} ${TAMANO_RAIZ_MIB} ext4
        \$lvmok{ }
        in_vg{ vg0 }
        lv_name{ root }
        method{ format }
        format{ }
        use_filesystem{ }
        filesystem{ ext4 }
        mountpoint{ / }
    .
    ${TAMANO_HOME_MIB} ${TAMANO_HOME_MIB} ${TAMANO_HOME_MIB} ext4
        \$lvmok{ }
        in_vg{ vg0 }
        lv_name{ home }
        method{ format }
        format{ }
        use_filesystem{ }
        filesystem{ ext4 }
        mountpoint{ /home }
    .
EOF_RECIPE
            ;;

        BIOS)
            RECETA="bios"

            cat > "$ARCHIVO_RECETA" <<EOF_RECIPE
particionado-bios ::
    ${TAMANO_ARRANQUE_MIB} ${TAMANO_ARRANQUE_MIB} ${TAMANO_ARRANQUE_MIB} free
        \$iflabel{ gpt }
        method{ biosgrub }
    .
    ${TAMANO_BOOT_MIB} ${TAMANO_BOOT_MIB} ${TAMANO_BOOT_MIB} ext4
        \$primary{ }
        method{ format }
        format{ }
        use_filesystem{ }
        filesystem{ ext4 }
        mountpoint{ /boot }
    .
    100 10000 -1 ext4
        \$defaultignore{ }
        \$primary{ }
        method{ lvm }
        device{ ${DISCO} }
        vg_name{ vg0 }
    .
    ${TAMANO_SWAP_MIB} ${TAMANO_SWAP_MIB} ${TAMANO_SWAP_MIB} linux-swap
        \$lvmok{ }
        in_vg{ vg0 }
        lv_name{ swap }
        method{ swap }
        format{ }
    .
    ${TAMANO_RAIZ_MIB} ${TAMANO_RAIZ_MIB} ${TAMANO_RAIZ_MIB} ext4
        \$lvmok{ }
        in_vg{ vg0 }
        lv_name{ root }
        method{ format }
        format{ }
        use_filesystem{ }
        filesystem{ ext4 }
        mountpoint{ / }
    .
    ${TAMANO_HOME_MIB} ${TAMANO_HOME_MIB} ${TAMANO_HOME_MIB} ext4
        \$lvmok{ }
        in_vg{ vg0 }
        lv_name{ home }
        method{ format }
        format{ }
        use_filesystem{ }
        filesystem{ ext4 }
        mountpoint{ /home }
    .
EOF_RECIPE
            ;;

        *)
            f_error "no se puede generar una receta para el firmware detectado."
            return 1
            ;;
    esac

    if [ ! -s "$ARCHIVO_RECETA" ]; then
        f_error "el archivo de receta está vacío o no se ha generado."
        return 1
    fi

    if ! command -v debconf-set >/dev/null 2>&1; then
        f_error "no se encuentra debconf-set."
        return 1
    fi

    debconf-set partman-auto/method lvm || return 1
    debconf-set partman-auto/expert_recipe_file "$ARCHIVO_RECETA" || return 1
    debconf-set partman-auto-lvm/new_vg_name vg0 || return 1

    echo "Receta generada: $ARCHIVO_RECETA"
    echo "Tipo de receta: $RECETA"
}

# Coordinar detección, cálculos y generación de la receta.
f_empezar_particionado() {
    f_asignar_prioridad || return 1
    f_detectar_tamano_disco || return 1

    f_asignar_arranque || return 1
    f_asignar_boot || return 1
    f_asignar_swap || return 1
    f_asignar_raiz || return 1
    f_asignar_home || return 1
    f_generar_receta || return 1

    echo "========================================"
    echo "Resumen del particionado"
    echo "========================================"
    echo "Disco: $DISCO"
    echo "Tamaño total: $TAMANO_DISCO_MIB MiB"
    echo "Arranque: $TAMANO_ARRANQUE_MIB MiB"
    echo "/boot: $TAMANO_BOOT_MIB MiB"
    echo "Espacio destinado a PV/VG LVM: $ESPACIO_LVM_MIB MiB"
    echo "Reserva libre en LVM: $RESERVA_LVM_MIB MiB"
    echo "swap: $TAMANO_SWAP_MIB MiB"
    echo "/: $TAMANO_RAIZ_MIB MiB"
    echo "/home: $TAMANO_HOME_MIB MiB"
}

# ============================================================
# Función principal
# ============================================================
f_inicio_script() {

    f_configurar_log || return 1

    echo "===================================================="
    echo "Preparando el particionado de Debian 13 (Trixie)"
    echo "===================================================="

    f_detectar_firmware || return 1
    f_empezar_particionado || return 1

    echo "===================================================="
    echo "Preparación del particionado finalizada."
    echo "Disco seleccionado: $DISCO"
    echo "La receta está preparada; partman todavía debe aplicarla."
    echo "Finalización: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "===================================================="
}

# ============================================================
# Zona de ejecución
# ============================================================

f_inicio_script "$@"
EOF

    chmod +x "$DIRECTORIO/particionado.sh" || return 1
    [ -s "$DIRECTORIO/particionado.sh" ] || return 1

}

# ============================================================
# Coordinación de la generación de archivos
# ============================================================

f_generar_archivos() {

    echo "Generando archivos de instalación..."

    f_generar_preseed || return 1
    f_generar_particionado || return 1

    echo "Todos los archivos se han generado correctamente."
}

# ============================================================
# Creación del directorio temporal
# ============================================================

f_crear_directorio_temporal() {

    echo "Creando directorio temporal..."

    DIRECTORIO_TEMPORAL=$(mktemp -d "$DIRECTORIO/.iso-auto.XXXXXX") || {
        echo "Error: no se ha podido crear el directorio temporal."
        return 1
    }

    ARCHIVO_MD5_ORIGINAL="$DIRECTORIO_TEMPORAL/md5sum-original.txt"
    ARCHIVO_MD5_NUEVO="$DIRECTORIO_TEMPORAL/md5sum.txt"

    NOMBRE_ISO_AUTO="debian-${VERSION_ULTIMA}-amd64-auto.iso"
    ISO_TEMPORAL="$DIRECTORIO_TEMPORAL/$NOMBRE_ISO_AUTO"
    ISO_PERSONALIZADA="$DIRECTORIO/$NOMBRE_ISO_AUTO"

    echo "Directorio temporal creado: $DIRECTORIO_TEMPORAL"
}

# ============================================================
# Extracción del manifiesto MD5
# ============================================================

f_extraer_md5() {

    echo "Extrayendo el manifiesto MD5 original..."

    if ! xorriso \
        -osirrox on \
        -indev "$ISO_LOCAL" \
        -extract /md5sum.txt "$ARCHIVO_MD5_ORIGINAL"; then

        echo "Error: no se ha podido extraer md5sum.txt."
        return 1
    fi

    if [ ! -s "$ARCHIVO_MD5_ORIGINAL" ]; then
        echo "Error: el manifiesto MD5 está vacío."
        return 1
    fi

    echo "Manifiesto MD5 extraído correctamente."
}

# ============================================================
# Actualización del manifiesto MD5
# ============================================================

f_actualizar_md5() {

    local suma_grub
    local suma_isolinux

    echo "Actualizando las sumas de comprobación..."

    # Eliminar las entradas anteriores de los archivos modificados.
    if ! awk '
        {
            ruta = $2
            sub(/^\.\//, "", ruta)

            if (ruta == "preseed.cfg" || ruta == "particionado.sh" || ruta == "boot/grub/grub.cfg" || ruta == "isolinux/txt.cfg") {
                next
            }

            print
        }
    ' "$ARCHIVO_MD5_ORIGINAL" > "$ARCHIVO_MD5_NUEVO"; then

        echo "Error: no se ha podido actualizar md5sum.txt."
        return 1
    fi

    # Añadir las sumas de los archivos de instalación.
    if ! (
        cd "$DIRECTORIO" &&
        md5sum \
            ./preseed.cfg \
            ./particionado.sh
    ) >> "$ARCHIVO_MD5_NUEVO"; then

        echo "Error: no se han podido calcular las sumas de instalación."
        return 1
    fi

    # Calcular las sumas de las configuraciones de arranque.
    suma_grub=$(md5sum "$DIRECTORIO_TEMPORAL/arranque/grub.cfg") || {
        echo "Error: no se ha podido calcular el MD5 de grub.cfg."
        return 1
    }

    suma_isolinux=$(md5sum "$DIRECTORIO_TEMPORAL/arranque/txt.cfg") || {
        echo "Error: no se ha podido calcular el MD5 de txt.cfg."
        return 1
    }

    # Extraer únicamente los hashes.
    suma_grub="${suma_grub%% *}"
    suma_isolinux="${suma_isolinux%% *}"

    # Añadir las sumas de los archivos de arranque.
    if ! {
        printf '%s  ./boot/grub/grub.cfg\n' "$suma_grub"
        printf '%s  ./isolinux/txt.cfg\n' "$suma_isolinux"
    } >> "$ARCHIVO_MD5_NUEVO"; then

        echo "Error: no se han podido añadir las sumas de arranque."
        return 1
    fi

    if [ ! -s "$ARCHIVO_MD5_NUEVO" ]; then
        echo "Error: el nuevo manifiesto MD5 está vacío."
        return 1
    fi

    echo "Manifiesto MD5 actualizado correctamente."
}

# ============================================================
# Introducción de archivos en la ISO
# ============================================================

f_insertar_archivos_iso() {

    echo "Introduciendo los archivos en la ISO..."

    if ! xorriso \
        -indev "$ISO_LOCAL" \
        -outdev "$ISO_TEMPORAL" \
        -map "$DIRECTORIO/preseed.cfg" /preseed.cfg \
        -map "$DIRECTORIO/particionado.sh" /particionado.sh \
        -map "$ARCHIVO_MD5_NUEVO" /md5sum.txt \
        -map "$DIRECTORIO_TEMPORAL/arranque/grub.cfg" /boot/grub/grub.cfg \
        -map "$DIRECTORIO_TEMPORAL/arranque/txt.cfg" /isolinux/txt.cfg \
        -boot_image any replay \
        -commit; then

        echo "Error: no se ha podido reconstruir la ISO."
        return 1
    fi

    if [ ! -s "$ISO_TEMPORAL" ]; then
        echo "Error: no se ha generado la ISO temporal."
        return 1
    fi

    echo "Archivos introducidos correctamente."
}

# ============================================================
# Comprobación de archivos incorporados
# ============================================================

f_comprobar_archivos_integrados() {

    local directorio_verificacion="$DIRECTORIO_TEMPORAL/verificacion"
    local archivo

    echo "Comprobando los archivos dentro de la ISO..."

    mkdir -p \
        "$directorio_verificacion/boot/grub" \
        "$directorio_verificacion/isolinux" || return 1

    if ! xorriso \
        -osirrox on \
        -indev "$ISO_TEMPORAL" \
        -extract /preseed.cfg "$directorio_verificacion/preseed.cfg" \
        -extract /particionado.sh "$directorio_verificacion/particionado.sh" \
        -extract /md5sum.txt "$directorio_verificacion/md5sum.txt" \
        -extract /boot/grub/grub.cfg "$directorio_verificacion/boot/grub/grub.cfg" \
        -extract /isolinux/txt.cfg "$directorio_verificacion/isolinux/txt.cfg"; then

        echo "Error: no se han podido extraer los archivos de la ISO."
        return 1
    fi

    # Comprobar los archivos de instalación.
    for archivo in preseed.cfg particionado.sh; do

        if ! cmp -s \
            "$DIRECTORIO/$archivo" \
            "$directorio_verificacion/$archivo"; then

            echo "Error: $archivo no coincide con el original."
            return 1
        fi

        echo "Archivo verificado: $archivo"
    done

    # Comprobar las configuraciones de arranque.
    if ! cmp -s \
        "$DIRECTORIO_TEMPORAL/arranque/grub.cfg" \
        "$directorio_verificacion/boot/grub/grub.cfg"; then

        echo "Error: grub.cfg no coincide con el archivo modificado."
        return 1
    fi

    if ! cmp -s \
        "$DIRECTORIO_TEMPORAL/arranque/txt.cfg" \
        "$directorio_verificacion/isolinux/txt.cfg"; then

        echo "Error: txt.cfg no coincide con el archivo modificado."
        return 1
    fi

    echo "Configuración GRUB verificada."
    echo "Configuración ISOLINUX verificada."

    # Comprobar el manifiesto MD5.
    if ! cmp -s \
        "$ARCHIVO_MD5_NUEVO" \
        "$directorio_verificacion/md5sum.txt"; then

        echo "Error: md5sum.txt no coincide con el manifiesto generado."
        return 1
    fi

    echo "Manifiesto MD5 verificado correctamente."
}

# ============================================================
# Comprobación del arranque de la ISO
# ============================================================

f_comprobar_arranque_iso() {

    echo "Comprobando la configuración de arranque..."

    INFO_ARRANQUE=$(xorriso \
        -indev "$ISO_TEMPORAL" \
        -report_el_torito plain 2>&1) || {

        echo "Error: no se ha podido comprobar el arranque."
        return 1
    }

    printf '%s\n' "$INFO_ARRANQUE"

    if ! printf '%s\n' "$INFO_ARRANQUE" |
        grep -Eqi '^El Torito boot img[[:space:]]*:[[:space:]]*[0-9]+[[:space:]]+BIOS([[:space:]]|$)'; then

        echo "Error: no se ha encontrado una entrada de arranque BIOS."
        return 1
    fi

    if ! printf '%s\n' "$INFO_ARRANQUE" |
        grep -Eqi '^El Torito boot img[[:space:]]*:[[:space:]]*[0-9]+[[:space:]]+UEFI([[:space:]]|$)'; then

        echo "Error: no se ha encontrado una entrada de arranque UEFI."
        return 1
    fi

    echo "Se han encontrado las entradas de arranque BIOS y UEFI."
}

# ============================================================
# Guardar la ISO personalizada
# ============================================================

f_guardar_iso() {

    echo "Guardando la ISO personalizada..."

    if ! mv -f -- "$ISO_TEMPORAL" "$ISO_PERSONALIZADA"; then
        echo "Error: no se ha podido guardar la ISO personalizada."
        return 1
    fi

    echo "ISO personalizada guardada: $ISO_PERSONALIZADA"
}

# ============================================================
# Limpieza de archivos temporales
# ============================================================

f_limpiar_temporales() {

    echo "Eliminando archivos temporales..."

    if [ -n "$DIRECTORIO_TEMPORAL" ] &&
       [ -d "$DIRECTORIO_TEMPORAL" ]; then

        rm -rf -- "$DIRECTORIO_TEMPORAL" || {
            echo "Error: no se ha podido limpiar el directorio temporal."
            return 1
        }

    fi

    DIRECTORIO_TEMPORAL=""
    ARCHIVO_MD5_ORIGINAL=""
    ARCHIVO_MD5_NUEVO=""
    ISO_TEMPORAL=""

    echo "Archivos temporales eliminados."
}

# ============================================================
# Extracción de configuración de arranque
# ============================================================

f_extraer_configuracion_arranque() {

    local directorio_arranque="$DIRECTORIO_TEMPORAL/arranque"

    echo "Extrayendo configuraciones de arranque..."

    mkdir -p "$directorio_arranque" || return 1

    if ! xorriso \
        -osirrox on \
        -indev "$ISO_LOCAL" \
        -extract /boot/grub/grub.cfg "$directorio_arranque/grub.cfg" \
        -extract /isolinux/txt.cfg "$directorio_arranque/txt.cfg"; then

        echo "Error: no se han podido extraer las configuraciones."
        return 1
    fi

    if [ ! -s "$directorio_arranque/grub.cfg" ] || \
       [ ! -s "$directorio_arranque/txt.cfg" ]; then

        echo "Error: alguno de los archivos de arranque está vacío o no existe."
        return 1
    fi

    if ! chmod u+w \
        "$directorio_arranque/grub.cfg" \
        "$directorio_arranque/txt.cfg"; then

        echo "Error: no se han podido modificar los permisos de los archivos de arranque."
        return 1
    fi

    echo "Configuraciones de arranque extraídas correctamente."
}


# ============================================================
# Modificación de GRUB (UEFI)
# ============================================================

f_modificar_grub() {

    local archivo="$DIRECTORIO_TEMPORAL/arranque/grub.cfg"
    local temporal="${archivo}.tmp"
    local comilla="'"

    echo "Modificando GRUB..."

    # Eliminar cualquier entrada anterior e insertar la nueva
    # inmediatamente después de la entrada original Install.
    if ! awk -v comilla="$comilla" '

        {
            # Eliminar la entrada personalizada anterior.
            if (eliminar) {
                if ($0 ~ /^}$/) {
                    eliminar=0
                }
                next
            }

            if ($0 ~ /^menuentry .*Automatic Installation.*\{$/) {
                eliminar=1
                next
            }

            print

            # Detectar el final de la entrada original Install.
            if (dentro_install) {

                if ($0 ~ /^}$/) {

                    print ""
                    print "menuentry " comilla "Automatic Installation" comilla " {"
                    print "    set background_color=black"
                    print "    linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg vga=788 --- quiet"
                    print "    initrd /install.amd/initrd.gz"
                    print "}"

                    insertado=1
                    dentro_install=0
                }

                next
            }

            # Identificar la entrada principal Install.
            if ($0 ~ /^menuentry --hotkey=i .*Install.*\{$/) {
                dentro_install=1
            }
        }

        END {
            if (eliminar || dentro_install || !insertado) {
                exit 1
            }
        }

    ' "$archivo" > "$temporal"; then

        rm -f -- "$temporal"

        echo "Error: no se ha podido insertar Automatic Installation después de Install en GRUB."
        return 1
    fi

    if ! chmod --reference="$archivo" "$temporal" ||
       ! mv -f -- "$temporal" "$archivo"; then

        rm -f -- "$temporal"

        echo "Error: no se ha podido guardar la configuración GRUB."
        return 1
    fi

    echo "Entrada automática insertada en el menú principal de GRUB."
}



# ============================================================
# Modificación de ISOLINUX (BIOS)
# ============================================================

f_modificar_isolinux() {

    local archivo="$DIRECTORIO_TEMPORAL/arranque/txt.cfg"
    local temporal="${archivo}.tmp"
    local temporal_limpio="${archivo}.clean.tmp"

    echo "Modificando ISOLINUX..."

    # Eliminar una entrada automática anterior, si existe.
    if ! awk '

        {
            if (eliminar) {

                if ($0 ~ /^label[[:space:]]/) {
                    eliminar=0
                } else {
                    next
                }
            }

            if ($0 ~ /^label automatic-installation$/) {
                eliminar=1
                next
            }

            print
        }

    ' "$archivo" > "$temporal_limpio"; then

        rm -f -- "$temporal_limpio"

        echo "Error: no se ha podido limpiar la configuración ISOLINUX."
        return 1
    fi

    # Insertar la entrada automática después del bloque Install.
    if ! awk '

        function insertar_automatico() {

            print ""
            print "label automatic-installation"
            print "    menu label Automatic Installation"
            print "    kernel /install.amd/vmlinuz"
            print "    append auto=true priority=critical preseed/file=/cdrom/preseed.cfg vga=788 initrd=/install.amd/initrd.gz --- quiet"
        }

        {
            # Insertar antes de la siguiente entrada,
            # una vez terminado el bloque Install.
            if (dentro_install && $0 ~ /^label[[:space:]]/) {

                insertar_automatico()

                insertado=1
                dentro_install=0
            }

            print

            # Identificar la entrada original Install.
            if ($0 ~ /^label install$/) {
                dentro_install=1
            }
        }

        END {

            # Si Install es la última entrada del archivo,
            # insertar Automatic Installation al final.
            if (dentro_install) {

                insertar_automatico()

                insertado=1
            }

            if (!insertado) {
                exit 1
            }
        }

    ' "$temporal_limpio" > "$temporal"; then

        rm -f -- "$temporal_limpio" "$temporal"

        echo "Error: no se ha podido insertar Automatic Installation después de Install en ISOLINUX."
        return 1
    fi

    rm -f -- "$temporal_limpio"

    if ! chmod --reference="$archivo" "$temporal" ||
       ! mv -f -- "$temporal" "$archivo"; then

        rm -f -- "$temporal"

        echo "Error: no se ha podido guardar la configuración ISOLINUX."
        return 1
    fi

    echo "Entrada automática insertada después de Install en ISOLINUX."
}



# ============================================================
# Comprobación de configuraciones de arranque
# ============================================================

f_comprobar_configuracion_arranque() {

    local grub="$DIRECTORIO_TEMPORAL/arranque/grub.cfg"
    local isolinux="$DIRECTORIO_TEMPORAL/arranque/txt.cfg"

    local linea_install_grub
    local linea_auto_grub
    local linea_advanced_grub

    local linea_install_isolinux
    local linea_auto_isolinux

    local cantidad_grub
    local cantidad_isolinux

    echo "Comprobando las nuevas entradas de arranque..."

    # --------------------------------------------------------
    # Comprobar GRUB
    # --------------------------------------------------------

    cantidad_grub=$(grep -Fxc "menuentry 'Automatic Installation' {" "$grub" || true)

    linea_install_grub=$(grep -n -m1 -F "menuentry --hotkey=i 'Install' {" "$grub" | cut -d: -f1)
    linea_auto_grub=$(grep -n -m1 -F "menuentry 'Automatic Installation' {" "$grub" | cut -d: -f1)
    linea_advanced_grub=$(grep -n -m1 -F "submenu --hotkey=a 'Advanced options ...' {" "$grub" | cut -d: -f1)

    if [ "$cantidad_grub" -ne 1 ] ||
       [ -z "$linea_install_grub" ] ||
       [ -z "$linea_auto_grub" ] ||
       [ -z "$linea_advanced_grub" ]; then

        echo "Error: las entradas principales de GRUB no son correctas."
        return 1
    fi

    if [ "$linea_auto_grub" -le "$linea_install_grub" ] ||
       [ "$linea_auto_grub" -ge "$linea_advanced_grub" ]; then

        echo "Error: Automatic Installation no está situada entre Install y Advanced options en GRUB."
        return 1
    fi

    if ! sed -n "${linea_auto_grub},$((linea_auto_grub + 3))p" "$grub" |
        grep -Fq "preseed/file=/cdrom/preseed.cfg"; then

        echo "Error: GRUB no contiene la ruta del archivo preseed."
        return 1
    fi

    echo "GRUB: entrada automática y posición verificadas."

    # --------------------------------------------------------
    # Comprobar ISOLINUX
    # --------------------------------------------------------

    cantidad_isolinux=$(grep -Fxc "label automatic-installation" "$isolinux" || true)

    linea_install_isolinux=$(grep -n -m1 -Fx "label install" "$isolinux" | cut -d: -f1)
    linea_auto_isolinux=$(grep -n -m1 -Fx "label automatic-installation" "$isolinux" | cut -d: -f1)

    if [ "$cantidad_isolinux" -ne 1 ] ||
       [ -z "$linea_install_isolinux" ] ||
       [ -z "$linea_auto_isolinux" ]; then

        echo "Error: las entradas de ISOLINUX no son correctas."
        return 1
    fi

    if [ "$linea_auto_isolinux" -le "$linea_install_isolinux" ]; then

        echo "Error: Automatic Installation no aparece después de Install en ISOLINUX."
        return 1
    fi

    if ! sed -n "${linea_auto_isolinux},$((linea_auto_isolinux + 3))p" "$isolinux" |
        grep -Fq "preseed/file=/cdrom/preseed.cfg"; then

        echo "Error: ISOLINUX no contiene la ruta del archivo preseed."
        return 1
    fi

    echo "ISOLINUX: entrada automática y posición verificadas."

    echo "Las dos configuraciones de arranque son correctas."
}


# ============================================================
# Función principal de personalización
# ============================================================

f_personalizar_iso() {

    echo "================================================"
    echo "Iniciando personalización de la ISO"
    echo "================================================"

    f_crear_directorio_temporal || return 1

    if f_extraer_md5 &&
       f_extraer_configuracion_arranque &&
       f_modificar_grub &&
       f_modificar_isolinux &&
       f_comprobar_configuracion_arranque &&
       f_actualizar_md5 &&
       f_insertar_archivos_iso &&
       f_comprobar_archivos_integrados &&
       f_comprobar_arranque_iso &&
       f_guardar_iso; then

        f_limpiar_temporales || return 1

        echo "================================================"
        echo "Personalización finalizada correctamente."
        echo "ISO generada: $ISO_PERSONALIZADA"
        echo "================================================"

    else

        echo "Error: ha fallado la personalización de la ISO."

        f_limpiar_temporales

        return 1

    fi
}

# ============================================================
# Función principal
# ============================================================

f_inicio() {

    echo "================================================"
    echo "       GESTOR DE IMÁGENES DEBIAN"
    echo "================================================"

    f_comprobar_dependencias || return 1
    f_comprobar_iso || return 1
    f_generar_archivos || return 1
    f_personalizar_iso || return 1

    echo "================================================"
    echo "Proceso finalizado correctamente."
    echo ""
    echo "ISO original: $ISO_NOMBRE"
    echo "ISO personalizada: $(basename "$ISO_PERSONALIZADA")"
    echo ""
    echo "Archivos incorporados:"
    echo " - preseed.cfg"
    echo " - particionado.sh"
    echo ""
    echo "Configuración de arranque:"
    echo " - Automatic Installation (UEFI)"
    echo " - Automatic Installation (BIOS)"
    echo "================================================"
}

# ============================================================
# Ejecución
# ============================================================

f_inicio "$@"
