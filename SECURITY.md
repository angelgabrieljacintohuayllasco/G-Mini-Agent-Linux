# Seguridad

## Cómo informar una vulnerabilidad

No abras un issue público. Escribe a **angelgabrieljacintohuayllasco@gmail.com**
con el asunto `[seguridad] G-Mini OS`, indicando la versión (nombre exacto de
la ISO o del paquete), los pasos para reproducirlo y el impacto. Respondemos
en un plazo de 7 días y publicamos el arreglo en una release nueva.

Los fallos de la propia aplicación G-Mini Agent se informan en su repositorio:
https://github.com/angelgabrieljacintohuayllasco/G-Mini-Agent

## Qué cubre este repositorio

- La configuración de las ISO (archiso y live-build) y los scripts `gmini-*`
  que van dentro.
- El PKGBUILD `g-mini-agent-bin`.
- Los scripts de build y los workflows de GitHub Actions.

## Decisiones conscientes de la sesión live

Solo en la sesión live (que vive en RAM y se borra al apagar):

- el usuario `gmini` tiene contraseña conocida (`gmini`) y usa `sudo` y polkit
  sin pedir contraseña;
- el llavero de GNOME no tiene contraseña, para que G-Mini Agent pueda guardar
  API keys sin un desbloqueo que la entrada automática no puede hacer.

Ninguno de estos ajustes pasa al sistema instalado: en Arch el instalador
crea el sistema desde cero y solo copia los ajustes de escritorio; en Debian
live-config los genera al arrancar y no están en la imagen que copia
Calamares. No dejes una sesión live expuesta a una red que no controlas.

## Cadena de suministro

- Los paquetes de G-Mini Agent se descargan de las releases del repositorio
  principal y se verifican contra el sha256 que GitHub calcula al subir cada
  archivo. El PKGBUILD fija el sha256 del AppImage.
- El AppImage se extrae leyendo su cabecera ELF; no se ejecuta durante el
  empaquetado.
- El live-build de Debian y el llavero con el que debootstrap verifica el
  archivo de Debian se descargan en versiones fijas y se comprueban por
  sha256 (con copia de respaldo en snapshot.debian.org).
- archiso, pacman y los paquetes de las ISO salen de los repositorios oficiales
  de Arch y Debian, que verifican sus firmas como en cualquier instalación.
- Las ISO no están firmadas. Verifica `SHA256SUMS` de la release antes de
  grabarlas.
