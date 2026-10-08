# WinTop

WinTop es un monitor de procesos para Windows escrito en PowerShell, inspirado en la experiencia de `htop` en Linux.

## Caracteristicas

- Barras por nucleo de CPU cuando Windows permite consultar los contadores del sistema.
- Barra de memoria fisica usada.
- Estado de la conexion activa (Wi-Fi o Ethernet) y trafico de descarga/subida en tiempo real.
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

## Deuda técnica y plan de estabilización

WinTop entra en una etapa de estabilización. Los puntos siguientes son **trabajos pendientes**, no defectos confirmados ni funcionalidades ya implementadas. Antes de publicar una versión estable, se verificará su comportamiento real en Windows 11 y, cuando sea posible, en PowerShell 5.1 y 7+.

| Prioridad | Área | Tarea y criterio de cierre |
| --- | --- | --- |
| Alta | Instalación | Separar la instalación de la ejecución normal. Iniciar `top.ps1` no debería copiar archivos ni modificar el `PATH` sin una acción explícita. Documentar instalación, actualización y desinstalación. |
| Alta | Lanzador y seguridad | Revisar `top.cmd` y el uso de `-ExecutionPolicy Bypass`; evitar excepciones innecesarias a la política de ejecución y verificar compatibilidad con Windows PowerShell 5.1 y PowerShell 7+. |
| Alta | Pruebas | Agregar verificaciones reproducibles para `-Once`, parámetros y salida no interactiva. Probar manualmente navegación, ordenamiento, filtros y cierre de procesos. |
| Media | Rendimiento | Medir el costo de consultas CIM por proceso; optimizar o incorporar caché si se confirma un problema. Manejar errores puntuales sin desactivar todas las consultas de usuario. |
| Media | Red | Revisar la elección del adaptador activo: la interfaz de mayor velocidad no necesariamente transporta el tráfico principal. Probar Wi-Fi, Ethernet, VPN y múltiples adaptadores. |
| Media | Robustez | Comprobar degradación ante permisos limitados, contadores CPU o CIM no disponibles y terminales pequeñas; evitar interrupciones y mensajes confusos. |
| Baja | Publicación | Incorporar una licencia explícita, actualizar las limitaciones conocidas y crear una primera release etiquetada únicamente tras validar los puntos críticos. |

### Plan de trabajo

1. **03/11/2026 — Baseline:** ejecutar y documentar pruebas en Windows 11.
2. **05/11/2026 — Instalación y lanzador:** desacoplar la instalación y revisar la política de ejecución.
3. **10/11/2026 — Pruebas y errores:** agregar regresiones y validar casos de degradación.
4. **12/11/2026 — Rendimiento y red:** medir CIM y revisar selección de interfaz.
5. **17/11/2026 — Cierre técnico:** licencia, documentación, validación final y evaluación de release.

Las fechas son bloques de trabajo previstos, no compromisos de entrega. El alcance excluye una reescritura y nuevas funcionalidades mayores. Después de la estabilización, el proyecto quedará en mantenimiento correctivo.
