# VuelosDW en MySQL para DBeaver y Power BI

Esta es una alternativa local cuando SQL Server no puede iniciar. Usa la misma
estructura dimensional de la P1 y crea la base `VuelosDW` en MySQL.

Desde PowerShell, ubicandose en `Practica1`:

```powershell
python -m pip install pymysql
powershell -ExecutionPolicy Bypass -File .\mysql\iniciar_mysql.ps1
python .\mysql\cargar_modelo_mysql.py
```

Conexion en DBeaver:

- Motor: MySQL
- Host: `127.0.0.1`
- Puerto: `3306`
- Base de datos: `VuelosDW`
- Usuario: `root`
- Password: `Vuelos2026!`

En Power BI usar **Obtener datos > Base de datos MySQL** con servidor
`127.0.0.1:3306` y base `VuelosDW`. Cargar las mismas ocho tablas y aplicar
las relaciones de `Practica2/README.md`.

El almacenamiento local queda en `Practica1/mysql/data/` y no debe subirse al
repositorio. El script se puede volver a ejecutar para reconstruir las tablas
desde los CSV de `Practica1/data/powerbi/`.
