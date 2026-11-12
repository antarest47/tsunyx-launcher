# Tsunyx Launcher

Un lanzador de aplicaciones para KDE Plasma 6 al estilo de las Actividades de GNOME:
una cuadrícula grande de iconos, por páginas, con búsqueda en vivo, que se abre desde
un botón del panel (o con un atajo de teclado). Nació porque los lanzadores que ya
había para Plasma (Kicker, Kickoff, FairyWren…) son menús emergentes o listas, y
ninguno da una cuadrícula completa que se recorra por páginas como la de GNOME.

Es parte de [Uzunyx](https://github.com/antarest47/uzunyx), pero funciona en
cualquier Plasma 6.

## Hecho con IA

Tsunyx está hecho con inteligencia artificial, y quiero que quede claro desde el
principio. No soy desarrollador/a: tengo las ideas, decido cómo se ve y cómo se
comporta cada cosa, y lo pruebo. El código lo escribió Claude (Anthropic), con Claude
Code, a partir de esas decisiones.

Todo se probó en mi PC y en máquinas virtuales, pero nadie lo revisó como lo haría un
equipo de desarrollo, ni hubo una auditoría de seguridad. Si lo vas a usar, pruébalo
primero en una máquina o partición que no te importe. Como dice la licencia, se
entrega sin garantías. Si encuentras un error, abre un Issue.

## Dos variantes

Este repositorio trae **dos variantes** que se instalan una al lado de la otra.
Comparten el código de la cuadrícula y la búsqueda, pero cambian la ventana:

- **Tsunyx Launcher** (`local.tsunyxlauncher`), la original. Su fondo cubre toda la
  pantalla, con el panel dibujado encima (como el dash de GNOME sobre la cuadrícula
  de apps) y la cuadrícula apartada del panel. Como cualquier menú de lanzador, no
  aparece en la barra de tareas, el paginador ni el selector de ventanas.
- **Tsunyx Launcher (Dialog)** (`local.tsunyxdialog`), una ventana flotante de tamaño
  fijo (1490×990 píxeles físicos) con borde propio, en vez de pantalla completa, para
  quien prefiera algo más parecido a una ventana emergente clásica. El borde está
  dibujado en QML (con el color de acento del esquema de colores activo) y no es una
  decoración de ventana real: `PlasmaCore.Dialog`, sobre el que está hecha esta
  variante, no puede recibir decoración de KWin.

## Funciones

- Cuadrícula de apps a pantalla completa y por páginas: se pasa de página deslizando
  en el panel táctil, con la rueda, con las flechas o con los puntos de página. En la
  configuración se puede cambiar por una sola lista que se desplaza.
- Búsqueda en vivo a medida que escribes, sin tener que hacer clic en un campo antes.
  Los resultados se agrupan por categoría (Aplicaciones, Archivos, Marcadores,
  Pestañas del navegador…), igual que en KRunner.
- Comandos de terminal, como en Tsunyx Search (más abajo): si KRunner reconoce el
  texto como un comando, primero aparece «Ejecutar en la terminal» (salvo que el
  nombre de algún resultado empiece igual que lo escrito), que lo corre en una
  terminal que queda abierta (`terminalCommand`, por defecto `konsole`).
- Calculadora (`2+2` y Enter deja `2+2=4`) y temporizadores (`5m`, `1h 30m té`,
  `temporizador 10 pizza`), con `uzunyx-timer`.
- Todo se maneja con el teclado, también entre páginas y entre secciones de
  resultados.
- Menú del clic derecho en cualquier icono: agregar o quitar de favoritos, fijar la
  app en el gestor de tareas del panel y las acciones propias de cada app.
- Animación al abrir y cerrar: los iconos salen volando del botón del panel en una ola
  (y vuelven al cerrar), mientras el fondo oscurecido y desenfocado aparece y se
  desvanece.
- Se cierra solo al perder el foco.
- Se pueden configurar el icono del panel, el tamaño de los iconos de la cuadrícula y
  si la cuadrícula va por páginas o como lista (en Tsunyx Launcher también cuánto se
  oscurece el fondo; no aplica a la variante Dialog, que no tiene fondo a pantalla
  completa).
- Interfaz en español (en inglés en los demás idiomas).

## Requisitos

- KDE Plasma 6.0 o superior y Qt 6.8 o superior, en Wayland o X11.
- `msgfmt` (del paquete `gettext`), solo para compilar una vez el catálogo de
  traducción al español.
- `kpackagetool6` y `kwriteconfig6`, que vienen con cualquier Plasma 6, para instalar
  el script de KWin que acompaña a cada variante (ver más abajo).

## Instalar

```sh
git clone https://github.com/antarest47/tsunyx-launcher.git
cd tsunyx-launcher
./install.sh
```

Esto instala **las dos** variantes: enlaza cada plasmoide en
`~/.local/share/plasma/plasmoids/`, compila e instala el catálogo en español de cada
una, e instala y activa el script de KWin de cada una. Los dos scripts hacen falta
porque la ventana de ninguno de los dos lanzadores es una ventana normal de app, con
decoración, a la que KWin le maneje solo la barra de tareas y el paginador:

- La ventana de Tsunyx Launcher nunca pasa a pantalla completa exclusiva (eso es lo
  que taparía el panel); sin su script, aparecería en la barra de tareas como una app
  abierta más.
- Tsunyx Launcher (Dialog) es un `PlasmaCore.Dialog`, que en Wayland no puede
  ubicarse ni darse bien el tamaño, y que no se oculta de la barra de tareas como
  puede hacerlo una ventana a pantalla completa. Su script lo centra, le da el tamaño
  en píxeles físicos según la escala de tu pantalla y lo oculta de la barra de
  tareas, el paginador y el selector de ventanas.

Después de correr el script, agrega cada widget a un panel a mano: clic derecho en el
panel → **Añadir elementos gráficos…** → busca «Tsunyx Launcher» (las dos variantes
aparecen por separado).

¿Solo quieres una variante? No agregues la otra al panel. Tener las dos instaladas no
molesta: son unos pocos archivos enlazados y un script de KWin que no actúa sobre
ninguna ventana hasta que agregas y abres ese lanzador.

## Tsunyx Search (cuadro de búsqueda en el panel)

`local.tsunyxsearch` es otro widget del panel: un cuadro de texto (con una lupa, como
la búsqueda de Tsunyx Launcher) que va en el propio panel, al lado del botón del
lanzador. Al escribir busca apps, archivos, marcadores, pestañas del navegador y más
con KRunner, igual que la búsqueda de Tsunyx Launcher, y muestra los resultados en una
ventana sobre el cuadro, alineada con su borde izquierdo (flechas para elegir, Enter
para abrir, Escape para borrar).

Si el buscador de comandos de KRunner reconoce el texto como un comando de terminal,
Enter lo ejecuta en Konsole con zsh desde la carpeta personal (con bash si no está
zsh; desde la 1.13, con el `ZDOTDIR` de Uzunyx si la terminal no lo trae), y la
terminal queda abierta en ese shell. El comando aparece primero salvo que el nombre de
algún resultado empiece igual que lo escrito: `fire` abre Firefox y `ls -la` se
ejecuta en la terminal. La terminal y el ancho del cuadro se pueden configurar
(`terminalCommand`, `fieldWidth`). Si el panel llega al 90 % del ancho de la pantalla,
el cuadro pasa a ser un botón con lupa.

## Paquete de Debian (para todo el sistema)

`make deb` arma `build/tsunyx-launcher_<versión>_all.deb` con el lanzador original (a
pantalla completa) y Tsunyx Search: el plasmoide en
`/usr/share/plasma/plasmoids/local.tsunyxlauncher`, el catálogo en español compilado
en `/usr/share/locale/es/LC_MESSAGES/` y el script de KWin que lo saca de la barra de
tareas en `/usr/share/kwin-wayland/scripts/` (activado por defecto). Para armarlo hace
falta `msgfmt` (paquete `gettext`). `install.sh` sigue siendo la instalación de
desarrollo, para un solo usuario.

## Configurar

Clic derecho en cualquiera de los dos botones del panel → **Configurar Tsunyx
Launcher…**:

- **Icono del panel**: cualquier icono del tema del sistema.
- **Tamaño de los iconos** de la cuadrícula.
- **Oscurecer el fondo**: opacidad de la capa oscura detrás de la cuadrícula (solo
  Tsunyx Launcher).
- **Disposición**: cuadrícula por páginas (por defecto) o lista que se desplaza.
- **Puntos de página**: mostrar u ocultar el indicador de página (solo por páginas).

## Desinstalar

Tsunyx Launcher:

```sh
rm ~/.local/share/plasma/plasmoids/local.tsunyxlauncher
rm ~/.local/share/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxlauncher.mo
kpackagetool6 --type=KWin/Script --remove tsunyxlauncherskiptaskbar
kwriteconfig6 --file kwinrc --group Plugins --key tsunyxlauncherskiptaskbarEnabled --delete
qdbus6 org.kde.KWin /KWin reconfigure
```

Tsunyx Launcher (Dialog):

```sh
rm ~/.local/share/plasma/plasmoids/local.tsunyxdialog
rm ~/.local/share/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxdialog.mo
kpackagetool6 --type=KWin/Script --remove tsunyxdialogcenter
kwriteconfig6 --file kwinrc --group Plugins --key tsunyxdialogcenterEnabled --delete
qdbus6 org.kde.KWin /KWin reconfigure
```

Después quita los widgets del panel desde su menú del clic derecho.

## Licencia

GPL-3.0-or-later.
