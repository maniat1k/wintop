# WinTop: Monitorea Procesos en Tiempo Real en Windows con PowerShell

![WinTop Running](https://i.imgur.com/your_image_link.png)  

## 🚀 Descripción  
**WinTop** es un script en PowerShell que te permite monitorear en tiempo real los **procesos más pesados** en **CPU** y **RAM**, ofreciendo una alternativa liviana al Administrador de Tareas.  

## 📌 Características  
- 🔹 **Top 10 procesos con mayor consumo de CPU y RAM**.  
- 🔹 **Refrescado automático** cada X segundos.  
- 🔹 **Sin instalación** de software adicional, solo PowerShell.  
- 🔹 **Código abierto y personalizable**.  

## 💻 **Cómo Usarlo**  

### 🔹 1. Descargar el Script  
Ejecutá este comando en PowerShell para descargarlo automáticamente:  

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/tuusuario/wintop/main/tops.ps1" -OutFile "tops.ps1"
🔹 2. Ejecutar WinTop
Para iniciar el monitoreo, corré el script en PowerShell:

powershell
Copiar
Editar
.\tops.ps1
🔹 3. Ajustar el Intervalo de Actualización
Si querés refrescar los datos cada 3 segundos en lugar de 5:

powershell
Copiar
Editar
Show-Top -RefreshRate 3
📸 Captura de Pantalla
(Podés agregar una imagen de WinTop en acción)

🛠️ Requisitos
Windows 10/11
PowerShell 5.1 o superior
🏗️ Contribuir
Si querés mejorar el script, cualquier PR es bienvenido.

📌 Repositorio en GitHub: https://github.com/maniat1k/wintop
