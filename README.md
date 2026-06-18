# WinTop

WinTop es un monitor de procesos para Windows escrito en PowerShell, inspirado en la experiencia de `htop` en Linux.

## Caracteristicas

- Barras por nucleo de CPU cuando Windows permite consultar los contadores del sistema.
- Barra de memoria fisica usada.
- Conteo de tareas, hilos activos y uptime.
- Tabla de procesos con PID, usuario, prioridad, hilos, memoria virtual, memoria residente, CPU, memoria y comando.
- CPU calculada por delta entre muestras, no por CPU acumulada desde el inicio del proceso.
- Ordenamiento, filtro y cierre de procesos desde el teclado.
- Fallbacks para entornos donde WMI/CIM o la consola interactiva esten restringidos.

## Uso

```powershell
.\top.ps1
```

La primera vez que ejecutes `top.ps1`, WinTop se autoinstala como comando `top` en:

```text
%LOCALAPPDATA%\Programs\WinTop
```

Tambien agrega esa carpeta al `PATH` de usuario y muestra un aviso. Desde ese momento podes usar:

```powershell
top
```

Si la terminal actual todavia no reconoce `top`, abri una terminal nueva.

Opciones:

```powershell
top -RefreshRate 1 -ProcessLimit 40 -SortBy mem
top -Once
```

Parametros:

- `-RefreshRate`: segundos entre refrescos. Por defecto: `2`.
- `-ProcessLimit`: cantidad maxima de filas visibles. Por defecto: `30`.
- `-SortBy`: orden inicial. Valores: `cpu`, `mem`, `pid`, `name`.
- `-Once`: renderiza una sola muestra y termina. Es util para pruebas.

## Teclas

- `q`: salir.
- `h`: mostrar ayuda corta.
- `c`: ordenar por CPU.
- `m`: ordenar por memoria.
- `p`: ordenar por PID.
- `n`: ordenar por nombre.
- `f`: filtrar por PID, usuario o comando.
- `k`: pedir un PID y ejecutar `Stop-Process -Confirm`.
- `+` / `-`: mostrar mas o menos filas.

## Requisitos

- Windows 10/11.
- PowerShell 5.1 o PowerShell 7+.

Algunos datos, como usuario del proceso o barras por nucleo, dependen de permisos y contadores del sistema. Si Windows los bloquea, WinTop sigue funcionando con la informacion disponible.
