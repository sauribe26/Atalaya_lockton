# Atalaya — Control de acceso por menús

Prueba técnica **Desarrollador Full Stack — Lockton Sekuritas**.

Solución web para registrar usuarios, autenticarlos y controlar dinámicamente los menús que cada uno puede ver y usar. La autorización se valida **en el servidor en cada petición**: ocultar la opción en la interfaz es solo comodidad, no seguridad.

---

## 1. Arquitectura

```
┌───────────────────────────── Atalaya.Web (IIS / IIS Express) ─────────────────────────────┐
│  Front (index.html, login.html, assets/)   ──fetch + Bearer JWT──►   API REST (/api/*)     │
│  Bootstrap 5 · JS módulos · Chart.js                                  Web API 2 · Swagger   │
│                                                                       │                     │
│                                         AutenticacionJwtHandler → [RequiereMenu("X")]       │
└──────────────────────────────────────────────────────────────────────┼─────────────────────┘
                                                                       ▼
                         Atalaya.Datos (repositorios, MySql.Data, solo procedimientos almacenados)
                                                                       ▼
                                          MySQL 8 · base de datos atalaya_acceso
```

| Proyecto | Responsabilidad |
|---|---|
| `src/Atalaya.Dominio` | Entidades, DTOs con validaciones, interfaces de repositorio, `HasherClaves` (PBKDF2), excepciones de negocio. No depende de nada. |
| `src/Atalaya.Datos` | Acceso a datos: llama los procedimientos almacenados con parámetros tipados (sin SQL concatenado). |
| `src/Atalaya.Web` | API REST (controladores, JWT, autorización por menú, manejo global de errores, Swagger) y el front estático que consume la API. |
| `database/` | Scripts de creación, procedimientos y datos iniciales. |
| `docs/` | Contrato técnico, documentación de la API, colección Postman, declaración de uso de IA. |

## 2. Requisitos

- Windows con **Visual Studio 2019/2022** (carga de trabajo "Desarrollo de ASP.NET y web") y **.NET Framework 4.8**.
- **IIS Express** (viene con Visual Studio).
- **MySQL 8.0** o superior (local o remoto).
- Descomprimir en una **ruta corta** (por ejemplo `C:\Atalaya`). Algunos paquetes NuGet tienen rutas internas largas y Windows limita las rutas a 260 caracteres.
- Conexión a internet la primera vez: NuGet restaura los paquetes y el front carga Bootstrap, Bootstrap Icons, Chart.js y la fuente desde CDN.

## 3. Instalación

### 3.1 Base de datos

```bash
mysql -u root -p < database/00_instalar_todo.sql
```

El script crea la base `atalaya_acceso`, las tablas, los procedimientos y los datos de prueba. Es idempotente: se puede correr varias veces y siempre deja el estado inicial.

Opcional, para usar un usuario de aplicación con permisos mínimos (ver `database/LEEME_BD.md`):

```sql
CREATE USER 'atalaya_app'@'localhost' IDENTIFIED BY 'una-clave-segura';
GRANT EXECUTE, SELECT ON atalaya_acceso.* TO 'atalaya_app'@'localhost';
```

### 3.2 Configuración (secretos fuera del código)

Los dos archivos con secretos **no están en el repositorio**. Se crean a partir de las plantillas:

```powershell
cd src\Atalaya.Web
copy ConnectionStrings.example.config ConnectionStrings.config
copy Secretos.example.config Secretos.config
```

- `ConnectionStrings.config`: servidor, usuario y clave de MySQL.
- `Secretos.config`: `Jwt:Clave`, una cadena aleatoria de 32 caracteres o más que firma los tokens.

### 3.3 Ejecución

1. Abrir `Atalaya.sln` en Visual Studio. Los paquetes NuGet se restauran solos.
2. Dejar `Atalaya.Web` como proyecto de inicio y presionar **F5**.
3. Se abre `http://localhost:52080/`, que redirige al inicio de sesión.

| URL | Qué es |
|---|---|
| `http://localhost:52080/login.html` | Aplicación web |
| `http://localhost:52080/swagger` | Documentación interactiva de la API (OpenAPI) |
| `http://localhost:52080/api/salud` | Chequeo de salud (API + base de datos) |

## 4. Usuarios de prueba

Son credenciales **ficticias**, solo para esta prueba.

| Usuario | Clave | Estado | Menús asignados |
|---|---|---|---|
| `admin` | `Admin#2026` | Activo | Todos (Tablero, Usuarios, Asignación, Bitácora, Clientes, Pólizas, Siniestros) |
| `analista` | `Analista#2026` | Activo | Tablero, Pólizas, Siniestros |
| `consulta` | `Consulta#2026` | Activo | Clientes, Pólizas |
| `auditor` | `Auditor#2026` | **Inactivo** | Bitácora (no puede ingresar: demuestra el control de estado) |

También se puede ingresar con el correo (`admin@atalaya.test`, etc.).

## 5. Escenario de validación (sección 3 de la prueba)

| Requisito | Cómo demostrarlo |
|---|---|
| Al menos dos usuarios | Vienen 4 en los datos iniciales. Se pueden crear más en **Usuarios → Nuevo usuario**. |
| Al menos cuatro menús | Vienen 7 menús en tres grupos (Control, Gestión, Operación). |
| Conjuntos de menús distintos | Ver la tabla anterior, o la **matriz de acceso** del Tablero. |
| Cada usuario ve solo sus menús | Ingresar como `analista` y luego como `consulta`: la barra lateral cambia. |
| Usuario no autorizado bloqueado en la API | Como `analista`, escribir `#/usuarios` en la URL: la pantalla "Sin acceso" muestra la respuesta **403** real del servidor. También en Swagger o Postman: `GET /api/users` con el token de `analista` → 403. |

Prueba rápida por consola (PowerShell):

```powershell
$r = Invoke-RestMethod -Method Post -Uri http://localhost:52080/api/auth/login `
     -ContentType 'application/json' -Body '{"login":"analista","clave":"Analista#2026"}'
Invoke-WebRequest -Uri http://localhost:52080/api/users -Headers @{ Authorization = "Bearer $($r.token)" }
# → 403 ACCESO_DENEGADO (y queda registrado en la Bitácora)
```

## 6. Seguridad

- **Contraseñas:** PBKDF2-SHA256 (`Rfc2898DeriveBytes`, mecanismo estándar de .NET), sal aleatoria de 16 bytes por usuario y 100.000 iteraciones. El número de iteraciones se guarda por usuario para poder subirlo sin invalidar las claves existentes. La comparación se hace en tiempo constante.
- **Autenticación:** JWT HS256 con vigencia de 8 horas. La clave de firma vive en `Secretos.config`, fuera del código fuente.
- **Autorización en el backend:** el atributo `[RequiereMenu("CODIGO")]` consulta la base **en cada petición**. Si a un usuario se le quita un menú o se inactiva, pierde el acceso de inmediato, aunque su token siga vigente.
- **Bloqueo:** 5 intentos fallidos seguidos bloquean la cuenta 15 minutos (HTTP 423).
- **Sin enumeración de usuarios:** usuario inexistente y clave incorrecta devuelven la misma respuesta (401).
- **Auditoría:** ingresos, fallos, bloqueos, accesos denegados y cambios de menús quedan en `bitacora_acceso`.
- **Inyección SQL:** todo pasa por procedimientos almacenados con parámetros tipados.
- **XSS:** el front escapa todo dato que pinta en pantalla.
- **Cabeceras:** `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`.

## 7. Documentación

- **API:** Swagger en `/swagger`, más `docs/API.md` y `docs/Atalaya.postman_collection.json` (el login guarda el token automáticamente).
- **Base de datos:** `database/LEEME_BD.md` (modelo entidad-relación y decisiones de diseño).
- **Manual de usuario:** dentro del aplicativo, en el ícono de ayuda **(?)** de la barra superior o en `#/manual`.
- **Contrato técnico:** `docs/CONTRATO.md`.
- **Uso de IA:** `docs/USO_IA.md`.
