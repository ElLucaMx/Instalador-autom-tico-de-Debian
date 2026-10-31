# Instalador automatizado de Debian 13

Herramienta para generar una ISO personalizada de Debian 13 (Trixie) con instalación desatendida mediante Preseed, detección automática del firmware y particionado dinámico con LVM.

El script descarga y verifica la imagen oficial de Debian, incorpora los archivos necesarios para automatizar la instalación y genera una ISO compatible con sistemas BIOS y UEFI.

## Características

- **Gestión automática de imágenes ISO:** detecta la última versión disponible de Debian y comprueba si existe una imagen local que pueda reutilizarse.
- **Verificación de integridad:** utiliza SHA-512 para comprobar que la imagen descargada o existente coincide con la suma oficial publicada por Debian.
- **Instalación desatendida:** configura Debian mediante un archivo Preseed generado automáticamente.
- **Detección de firmware:** identifica si el equipo utiliza BIOS o UEFI y genera la receta de particionado correspondiente.
- **Selección automática del disco:** detecta los discos disponibles, excluye los dispositivos USB y selecciona un disco según una prioridad establecida.
- **Particionado dinámico:** calcula los tamaños de las particiones y volúmenes lógicos en función del espacio disponible y de la memoria RAM.
- **Gestión mediante LVM:** crea un grupo de volúmenes llamado `vg0` con volúmenes lógicos independientes para `swap`, `/` y `/home`.
- **Arranque BIOS y UEFI:** incorpora una entrada de instalación automática en los menús de GRUB e ISOLINUX.
- **Verificación de la ISO generada:** comprueba los archivos incorporados, actualiza el manifiesto MD5 y verifica las entradas de arranque.
- **Registro de instalación:** conserva un log con información sobre las diferentes fases del proceso.

## Requisitos

### Sistema de generación

Se necesita un sistema Linux con las siguientes herramientas:

| Dependencia | Función |
|---|---|
| `curl` | Consultar Debian y descargar la imagen ISO. |
| `xorriso` | Extraer, modificar y reconstruir la imagen ISO. |
| `sha512sum` | Verificar la integridad de la ISO original. |
| `md5sum` | Actualizar el manifiesto de comprobación de la ISO. |
| `awk`, `sed`, `grep` | Procesar información y modificar configuraciones. |
| `sort`, `tail`, `cut` | Ordenar versiones y procesar resultados. |
| `mktemp`, `cmp` | Gestionar archivos temporales y verificar archivos. |

También se utilizan otras utilidades habituales de GNU/Linux, como `basename`, `dirname`, `mv`, `rm`, `chmod`, `mkdir`, `cat` y `date`.

### Instalación de dependencias

En Debian:

```bash
sudo apt update
sudo apt install -y curl xorriso
```

El resto de las herramientas utilizadas forman parte de las utilidades habituales del sistema.

## Instalación y ejecución

Clona el repositorio:

```bash
git clone <URL_DEL_REPOSITORIO>
```

Accede al directorio:

```bash
cd <DIRECTORIO_DEL_REPOSITORIO>
```

Concede permisos de ejecución:

```bash
chmod +x construir-iso-debian.sh
```

Ejecuta el script:

```bash
./construir-iso-debian.sh
```

El script trabaja sobre el directorio donde se encuentra y deja allí la ISO personalizada junto con los archivos generados.

## Funcionamiento

El proceso se divide en cuatro fases principales.

### 1. Comprobación de dependencias

Antes de comenzar, el script comprueba que todas las herramientas necesarias estén disponibles.

Si falta alguna dependencia, el proceso se detiene e indica cuál es la herramienta que debe instalarse.

### 2. Detección y descarga de Debian

El script consulta el repositorio oficial de imágenes de Debian:

`https://cdimage.debian.org/debian-cd/current/amd64/iso-cd`

A partir de la información obtenida, identifica la última versión disponible y comprueba si existe una imagen local.

El comportamiento depende del resultado:

- Si no existe ninguna ISO, descarga la última versión.
- Si existe una ISO de la última versión y supera la verificación SHA-512, la reutiliza.
- Si existe una ISO antigua, descarga la versión más reciente.
- Si la ISO local no supera la comprobación de integridad, descarga una copia nueva.
- Si encuentra varias imágenes ISO compatibles, detiene el proceso para evitar seleccionar una incorrectamente.

La imagen descargada se verifica antes de sustituir la anterior o utilizarla para generar la ISO personalizada.

### 3. Generación de los archivos de instalación

Se generan dos archivos que se incorporarán a la imagen:

| Archivo | Función |
|---|---|
| `preseed.cfg` | Define la configuración desatendida del instalador Debian. |
| `particionado.sh` | Detecta el hardware y genera la receta de particionado dinámico. |

#### Configuración de Preseed

El archivo `preseed.cfg` automatiza los siguientes apartados:

- Idioma: español (`es_ES.UTF-8`).
- Distribución del teclado: español.
- Configuración de red mediante DHCP.
- Nombre del equipo: `elhuesaso`.
- Repositorio de paquetes: `ftp.cica.es/debian`.
- Usuario y contraseña.
- Zona horaria: `Europe/Madrid`.
- Particionado mediante LVM.
- Instalación de GNOME.
- Instalación de Flatpak.
- Integración de Flathub.
- Instalación de OpenSSH Server.
- Actualización segura de paquetes.
- Instalación de GRUB.
- Registro de las diferentes fases de instalación.

#### Particionado dinámico

El script `particionado.sh` se ejecuta durante la instalación, antes de que el particionador de Debian aplique los cambios.

Su funcionamiento se divide en varias operaciones:

**Detección del firmware**

Comprueba la existencia de `/sys/firmware/efi` para determinar si el sistema ha iniciado mediante UEFI o BIOS.

**Detección y selección del disco**

Utiliza `list-devices disk` para obtener los discos disponibles.

Posteriormente, consulta sus rutas en `/sys/block` y excluye los dispositivos USB.

La selección se realiza mediante el siguiente orden de prioridad:

| Prioridad | Tipo de disco |
|---|---|
| 1 | NVMe |
| 2 | SSD o dispositivo no rotacional |
| 3 | HDD o dispositivo rotacional |

La clasificación es orientativa y se basa en el tipo de dispositivo detectado, no en pruebas reales de velocidad.

**Cálculo del espacio**

Una vez seleccionado el disco, obtiene su capacidad y calcula los tamaños necesarios para cada partición y volumen lógico.

### 4. Personalización de la ISO

Una vez generados los archivos, comienza la modificación de la imagen original.

Las operaciones realizadas son:

1. Comprobar que existen los archivos necesarios dentro de la ISO.
2. Crear un directorio temporal.
3. Extraer el manifiesto `md5sum.txt`.
4. Extraer las configuraciones de GRUB e ISOLINUX.
5. Incorporar una entrada de instalación automática en GRUB.
6. Incorporar una entrada de instalación automática en ISOLINUX.
7. Comprobar que las nuevas entradas están correctamente ubicadas.
8. Actualizar las sumas MD5 de los archivos modificados.
9. Incorporar los archivos de instalación a la ISO.
10. Extraer y comparar los archivos incorporados para verificar su integridad.
11. Comprobar que la ISO conserva las entradas de arranque BIOS y UEFI.
12. Guardar la imagen personalizada y eliminar los archivos temporales.

La entrada de instalación automática aparece junto a la opción de instalación convencional, permitiendo conservar ambas posibilidades.

## Estructura del particionado

El particionado se genera dinámicamente en función del firmware detectado, la capacidad del disco y la memoria RAM disponible.

Se utiliza una tabla de particiones GPT tanto para BIOS como para UEFI.

### Particiones de arranque

| Partición | Tamaño | UEFI | BIOS |
|---|---:|---|---|
| EFI / BIOS Boot | 512 MiB / 2 MiB | EFI System Partition | BIOS Boot Partition |
| `/boot` | 1024 MiB | ext4 | ext4 |

La partición de arranque depende del firmware:

- **UEFI:** reserva 512 MiB para la partición EFI.
- **BIOS:** reserva 2 MiB para la partición BIOS Boot, necesaria para GRUB en GPT.

La partición `/boot` se mantiene fuera de LVM.

### Volúmenes lógicos LVM

El espacio restante se utiliza para crear un grupo de volúmenes denominado `vg0`.

Dentro de este grupo se generan tres volúmenes lógicos:

| Volumen lógico | Punto de montaje | Tamaño |
|---|---|---|
| `swap` | Swap | 50 % de la RAM, con un máximo de 32 GiB |
| `root` | `/` | 55 % del espacio restante |
| `home` | `/home` | Todo el espacio restante |

Se reserva un margen de 64 MiB dentro del grupo de volúmenes LVM.

### Ejemplo de distribución

En un disco virtual de 20 GiB, con aproximadamente 2 GiB de RAM y firmware UEFI, el resultado puede ser similar al siguiente:

| Elemento | Tamaño aproximado |
|---|---:|
| Partición EFI | 512 MiB |
| `/boot` | 1024 MiB |
| Swap | 977 MiB |
| `/` | 9846 MiB |
| `/home` | 8057 MiB |
| Reserva libre en LVM | 64 MiB |

Los tamaños se calculan automáticamente, por lo que pueden variar dependiendo del disco y la memoria RAM detectados.

## Archivos generados

Durante la ejecución se generan los siguientes archivos:

| Archivo | Descripción |
|---|---|
| `preseed.cfg` | Configuración de instalación desatendida. |
| `particionado.sh` | Script de detección y particionado dinámico. |
| `debian-VERSION-amd64-auto.iso` | Imagen Debian personalizada. |

El nombre de la ISO incluye la versión de Debian utilizada.

## Registro de instalación

Durante la instalación se genera un registro con marcas de tiempo que permite consultar las diferentes fases del proceso.

El registro se conserva en el sistema instalado en:

```bash
/var/log/installer/instalacion.log
```

Para consultarlo:

```bash
sudo cat /var/log/installer/instalacion.log
```

### Ejemplo de ejecución

El siguiente registro corresponde a una instalación automatizada de Debian 13 (Trixie) en una máquina virtual:

```text
root@elhuesaso:~# cat /var/log/installer/instalacion.log
2026-10-31 21:42:49 - Inicio de la instalación automatizada
2026-10-31 21:42:49 - La configuración de red se delegará a netcfg
2026-10-31 21:43:20 - Iniciando configuración dinámica del particionado
2026-10-31 21:43:20 - ===================================================
2026-10-31 21:43:20 - Registro preparado
===================================================
Preparando el particionado de Debian 13 (Trixie)
===================================================
2026-10-31 21:43:20 - Firmware detectado: UEFI
File descriptor 3 (pipe:[1573]) leaked on pvs invocation. Parent PID 6239: /bin/sh
File descriptor 4 (/dev/pts/0) leaked on pvs invocation. Parent PID 6239: /bin/sh
File descriptor 5 (/dev/pts/0) leaked on pvs invocation. Parent PID 6239: /bin/sh
File descriptor 6 (/dev/pts/0) leaked on pvs invocation. Parent PID 6239: /bin/sh
Disco válido: /dev/vda
Candidato: /dev/vda (HDD/rotacional, prioridad 1)
Disco seleccionado: /dev/vda (HDD/rotacional)
Tamaño del disco seleccionado: 20480 MiB
Espacio para arranque: 512 MiB
Espacio para /boot: 1024 MiB
RAM detectada: 1954 MiB
Espacio para swap: 977 MiB
Espacio para /: 9846 MiB
Espacio para /home: 8057 MiB
Receta generada: /tmp/receta-particionado
Tipo de receta: uefi
===================================================
Resumen del particionado
===================================================
Disco: /dev/vda
Tamaño total: 20480 MiB
Arranque: 512 MiB
/boot: 1024 MiB
Espacio destinado a PV/VG LVM: 18944 MiB
Reserva libre en LVM: 64 MiB
swap: 977 MiB
/: 9846 MiB
/home: 8057 MiB
===================================================
Preparación del particionado finalizada.
Disco seleccionado: /dev/vda
La receta está preparada; partman todavía debe aplicarla.
Finalización: 2026-10-31 21:43:20
===================================================
2026-10-31 21:43:20 - Receta de particionado preparada
2026-10-31 21:49:27 - Particionado completado
2026-10-31 21:49:27 - Instalación del sistema base y paquetes completada
2026-10-31 21:49:27 - Iniciando configuración de Flathub
2026-10-31 21:49:27 - Repositorio Flathub configurado
root@elhuesaso:~#
```

El registro permite comprobar:

- El inicio de la instalación automatizada.
- La detección del firmware utilizado.
- La identificación y selección del disco.
- El cálculo de los tamaños de las particiones y volúmenes lógicos.
- La generación de la receta de particionado.
- La finalización del particionado.
- La instalación del sistema base y los paquetes.
- La configuración del repositorio Flathub.

Los mensajes `File descriptor ... leaked` son advertencias emitidas durante las invocaciones de `pvs`. Se muestran en este ejemplo porque forman parte de la salida registrada durante la ejecución.

## Consideraciones importantes

- El particionado automático confirma la escritura de la tabla de particiones y la configuración LVM sin intervención del usuario.
- El disco seleccionado puede contener datos anteriores. La instalación puede eliminarlos al aplicar el particionado.
- Es recomendable probar la ISO en una máquina virtual antes de utilizarla en hardware físico.
- La selección automática del disco se basa en los criterios definidos por el script y no garantiza que siempre se elija el disco que el usuario desea.
- Es necesario disponer de conexión a Internet durante la instalación para descargar paquetes y configurar Flathub.
- La imagen original se conserva como base para generar la ISO personalizada.
- La integridad de la ISO original se comprueba mediante SHA-512. El manifiesto MD5 de la imagen personalizada se actualiza para reflejar los archivos modificados.

**Importante antes de publicar el repositorio:** el archivo Preseed contiene hashes de contraseña predefinidos para `root` y `usuario`. Aunque no sean contraseñas en texto plano, deben sustituirse por hashes propios antes de publicar la herramienta. De lo contrario, cualquier persona que utilice la ISO generada podría conocer las credenciales configuradas.

## Tecnologías utilizadas

- Debian 13 (Trixie).
- Debian Installer.
- Preseed.
- Bash.
- LVM.
- GRUB.
- ISOLINUX.
- xorriso.
- Flatpak.
- Flathub.
