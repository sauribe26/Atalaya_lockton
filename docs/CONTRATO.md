# Atalaya — Contrato técnico compartido (BD ↔ API ↔ Front)

Fuente de verdad para los tres frentes. Si algo cambia, se cambia AQUÍ primero.

## Stack
- .NET Framework 4.8, C#, ASP.NET Web API 2 (sin MVC), Swashbuckle 5.6 (Swagger en `/swagger`).
- MySQL 8 (BD `atalaya_acceso`, servidor de desarrollo = el mismo de Motoseguridad; la cadena real vive SOLO en `src/Atalaya.Web/ConnectionStrings.config`, ignorado por git).
- Front: HTML + JavaScript (vanilla, ES modules) + Bootstrap 5.3.3 + Bootstrap Icons 1.11.3 + Chart.js 4.4.1 (CDN jsdelivr). Servido por el MISMO sitio IIS que la API (raíz `/` = front, `/api/*` = API). Sin Vue/React.
- Puerto fijo IIS Express: `http://localhost:52080/`.

## Estructura de carpetas
```
Atalaya/
  Atalaya.sln
  README.md
  .gitignore
  database/
    01_esquema.sql            (CREATE DATABASE + tablas + índices + FKs)
    02_procedimientos.sql     (todos los SPs)
    03_datos_iniciales.sql    (menús, usuarios demo con hash PBKDF2, asignaciones, datos de negocio demo)
    00_instalar_todo.sql      (concatenación de 01+02+03 para correr en un solo paso)
  docs/
    CONTRATO.md, API.md, Atalaya.postman_collection.json, USO_IA.md
  src/
    Atalaya.Dominio/   (class library net48: Entidades, DTOs, Seguridad/HasherClaves.cs, interfaces de repositorio)
    Atalaya.Datos/     (class library net48: ConexionMySql, Repositorios que llaman SPs con MySql.Data)
    Atalaya.Web/       (Web Application net48: API + front estático)
      App_Start/  Controllers/  Seguridad/  Filtros/  Global.asax  Web.config
      ConnectionStrings.config (ignorado)  ConnectionStrings.example.config
      Secretos.config (ignorado: appSettings con Jwt:Clave)  Secretos.example.config
      index.html  login.html  assets/css/  assets/js/  assets/img/
```

## Seguridad de contraseñas (compartido BD ↔ API)
PBKDF2 con `Rfc2898DeriveBytes(clave, sal, iteraciones, HashAlgorithmName.SHA256)`:
- clave en UTF-8, sal aleatoria de 16 bytes (`RNGCryptoServiceProvider`), 100000 iteraciones, hash de 32 bytes.
- Se guardan `hash_clave` y `sal_clave` en **Base64**, e `iteraciones` en columna aparte (permite subirlas sin romper usuarios viejos).
- Comparación en tiempo constante.
- Node equivalente para el seed: `crypto.pbkdf2Sync(clave,'utf8' buffer, salBuffer, 100000, 32, 'sha256')`.

Bloqueo: 5 intentos fallidos seguidos → `bloqueado_hasta = NOW() + 15 min`. Login OK resetea `intentos_fallidos`.

## Base de datos `atalaya_acceso` (utf8mb4_unicode_ci, InnoDB)

### usuario
| columna | tipo |
|---|---|
| id_usuario | INT AUTO_INCREMENT PK |
| nombre | VARCHAR(120) NOT NULL |
| usuario | VARCHAR(50) NOT NULL UNIQUE |
| correo | VARCHAR(150) NOT NULL UNIQUE |
| hash_clave | VARCHAR(255) NOT NULL |
| sal_clave | VARCHAR(255) NOT NULL |
| iteraciones | INT NOT NULL DEFAULT 100000 |
| estado | TINYINT(1) NOT NULL DEFAULT 1 (1 activo, 0 inactivo) |
| intentos_fallidos | INT NOT NULL DEFAULT 0 |
| bloqueado_hasta | DATETIME NULL |
| ultimo_acceso | DATETIME NULL |
| fecha_creacion | DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP |
| creado_por | INT NULL FK usuario |

### menu
| columna | tipo |
|---|---|
| id_menu | INT AUTO_INCREMENT PK |
| codigo | VARCHAR(40) NOT NULL UNIQUE (identificador funcional, ej. `USUARIOS`) |
| nombre | VARCHAR(80) NOT NULL |
| descripcion | VARCHAR(255) NOT NULL |
| ruta | VARCHAR(120) NOT NULL (ruta del front, ej. `#/usuarios`) |
| icono | VARCHAR(60) NOT NULL (clase Bootstrap Icons sin `bi-`, ej. `people`) |
| grupo | VARCHAR(40) NOT NULL (`Gestión`, `Operación`, `Control`) |
| orden | INT NOT NULL DEFAULT 0 |
| estado | TINYINT(1) NOT NULL DEFAULT 1 |
| fecha_creacion | DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP |

### usuario_menu  (PK compuesta id_usuario+id_menu, FKs con ON DELETE CASCADE)
| id_usuario | id_menu | fecha_asignacion DATETIME DEFAULT CURRENT_TIMESTAMP | asignado_por INT NULL |

### bitacora_acceso (auditoría)
| id_bitacora BIGINT PK | fecha DATETIME DEFAULT CURRENT_TIMESTAMP | id_usuario INT NULL | usuario_texto VARCHAR(50) NULL | evento VARCHAR(30) NOT NULL | recurso VARCHAR(150) NULL | ip VARCHAR(45) NULL | detalle VARCHAR(255) NULL |
Eventos: `LOGIN_OK`, `LOGIN_FALLIDO`, `LOGIN_BLOQUEADO`, `ACCESO_DENEGADO`, `USUARIO_CREADO`, `USUARIO_ESTADO`, `MENUS_ACTUALIZADOS`. Índices por (fecha), (evento, fecha).

### Datos de negocio demo (ficticios, broker de seguros)
- `cliente` (id_cliente, nit VARCHAR(20), razon_social, sector, ciudad, fecha_alta DATE)
- `poliza` (id_poliza, numero VARCHAR(30) UNIQUE, id_cliente FK, ramo, aseguradora, prima DECIMAL(14,0), vigencia_desde DATE, vigencia_hasta DATE, estado VARCHAR(20) `VIGENTE|POR_RENOVAR|VENCIDA`)
- `siniestro` (id_siniestro, numero VARCHAR(30) UNIQUE, id_poliza FK, fecha_aviso DATE, descripcion, valor_reclamado DECIMAL(14,0), estado VARCHAR(20) `ABIERTO|EN_AJUSTE|PAGADO|OBJETADO`)
8-10 clientes, ~15 pólizas, ~10 siniestros. Nombres inventados (nada real).

### Menús semilla (7)
| codigo | nombre | ruta | icono | grupo | orden |
|---|---|---|---|---|---|
| TABLERO | Tablero | #/tablero | speedometer2 | Control | 1 |
| USUARIOS | Usuarios | #/usuarios | people | Gestión | 2 |
| ASIGNACION | Asignación de menús | #/asignacion | diagram-3 | Gestión | 3 |
| AUDITORIA | Bitácora de accesos | #/auditoria | shield-check | Control | 4 |
| CLIENTES | Clientes | #/clientes | building | Operación | 5 |
| POLIZAS | Pólizas | #/polizas | file-earmark-text | Operación | 6 |
| SINIESTROS | Siniestros | #/siniestros | exclamation-diamond | Operación | 7 |

### Usuarios semilla (credenciales de PRUEBA, no reales)
| usuario | correo | clave | estado | menús |
|---|---|---|---|---|
| admin | admin@atalaya.test | Admin#2026 | activo | los 7 |
| analista | analista@atalaya.test | Analista#2026 | activo | TABLERO, POLIZAS, SINIESTROS |
| consulta | consulta@atalaya.test | Consulta#2026 | activo | CLIENTES, POLIZAS |
| auditor | auditor@atalaya.test | Auditor#2026 | INACTIVO | AUDITORIA |

## Procedimientos almacenados (todos con parámetros `p_*`; el API SIEMPRE llama SPs, nunca SQL concatenado)
Columnas de salida exactamente con estos alias (snake_case):

| SP | Parámetros | Resultado |
|---|---|---|
| `sp_usuario_crear` | p_nombre, p_usuario, p_correo, p_hash_clave, p_sal_clave, p_iteraciones, p_estado, p_creado_por | 1 fila `id_usuario` (SIGNAL SQLSTATE '45000' MESSAGE_TEXT 'USUARIO_DUPLICADO' / 'CORREO_DUPLICADO' si existen) |
| `sp_usuario_listar` | p_buscar (NULL = todos; busca en nombre/usuario/correo) | id_usuario, nombre, usuario, correo, estado, ultimo_acceso, fecha_creacion, total_menus |
| `sp_usuario_obtener` | p_id_usuario | mismas columnas que listar |
| `sp_usuario_obtener_para_login` | p_login (usuario O correo) | id_usuario, nombre, usuario, correo, hash_clave, sal_clave, iteraciones, estado, intentos_fallidos, bloqueado_hasta |
| `sp_usuario_registrar_login` | p_id_usuario, p_exitoso (TINYINT), p_ip | 1 fila: intentos_fallidos, bloqueado_hasta (aplica regla de bloqueo 5/15min; si exitoso resetea y pone ultimo_acceso=NOW()) |
| `sp_usuario_cambiar_estado` | p_id_usuario, p_estado | filas_afectadas |
| `sp_menu_listar` | p_solo_activos TINYINT | id_menu, codigo, nombre, descripcion, ruta, icono, grupo, orden, estado, total_usuarios |
| `sp_usuario_menus_listar` | p_id_usuario | menús ACTIVOS asignados: id_menu, codigo, nombre, descripcion, ruta, icono, grupo, orden, fecha_asignacion |
| `sp_usuario_menus_reemplazar` | p_id_usuario, p_ids_menu VARCHAR(1000) CSV (`"1,3,5"`, vacío = quitar todo), p_asignado_por | en transacción: borra los que no estén y agrega los nuevos; devuelve agregados, retirados |
| `sp_usuario_tiene_menu` | p_id_usuario, p_codigo_menu | 1 fila `autorizado` (1/0): usuario activo + menú activo + asignado |
| `sp_bitacora_registrar` | p_id_usuario, p_usuario_texto, p_evento, p_recurso, p_ip, p_detalle | — |
| `sp_bitacora_listar` | p_evento (NULL=todos), p_limite | id_bitacora, fecha, id_usuario, usuario_texto, evento, recurso, ip, detalle |
| `sp_tablero_kpis` | — | **4 resultsets**: (1) 1 fila: usuarios_total, usuarios_activos, menus_activos, asignaciones_total, logins_hoy, denegados_7d, fallidos_7d, bloqueados_ahora; (2) serie 14 días: dia DATE, logins_ok, logins_fallidos, accesos_denegados (días sin datos en 0); (3) uso por menú: codigo, nombre, total_usuarios; (4) matriz: id_usuario, usuario, codigo (filas de usuario_menu) |
| `sp_cliente_listar` | — | id_cliente, nit, razon_social, sector, ciudad, fecha_alta, polizas_vigentes |
| `sp_poliza_listar` | — | id_poliza, numero, cliente, ramo, aseguradora, prima, vigencia_desde, vigencia_hasta, estado, dias_para_vencer |
| `sp_siniestro_listar` | — | id_siniestro, numero, poliza, cliente, fecha_aviso, descripcion, valor_reclamado, estado |

## API REST (JSON camelCase; fechas ISO 8601; valores en pesos como entero)

Autenticación: JWT HS256 en `Authorization: Bearer <token>`, 8 h, claims `sub`=id_usuario, `unique_name`=usuario, `name`=nombre, `jti`. Clave de firma en `Secretos.config` (appSetting `Jwt:Clave`, ≥32 chars), emisor `Atalaya`.

**Autorización en backend**: atributo `[RequiereMenu("CODIGO")]` → consulta `sp_usuario_tiene_menu` EN CADA PETICIÓN (no confía en el token: si se le quita el menú o se inactiva el usuario, el acceso se corta de inmediato). Si falla → 403 + registro `ACCESO_DENEGADO` en bitácora.

Formato de error uniforme:
```json
{ "estado": 403, "codigo": "ACCESO_DENEGADO", "mensaje": "No tiene autorización para el menú USUARIOS.", "detalles": null, "traza": "c1f0..." }
```
`detalles` = diccionario campo → mensaje en errores de validación (400).

| Método | Ruta | Auth | Menú requerido | Cuerpo / respuesta |
|---|---|---|---|---|
| GET | /api/salud | anónimo | — | `{ "estado":"ok", "baseDatos":"ok", "hora":"..." }` |
| POST | /api/auth/login | anónimo | — | in `{ "login":"admin", "clave":"..." }` → 200 `{ token, expiraEn, usuario:{id,nombre,usuario,correo}, menus:[Menu] }`; 400 validación; 401 `CREDENCIALES_INVALIDAS`; 403 `USUARIO_INACTIVO`; 423 `USUARIO_BLOQUEADO` (mensaje incluye minutos restantes) |
| GET | /api/auth/yo | token | — | `{ usuario:{...}, menus:[Menu] }` (menú dinámico del usuario autenticado) |
| GET | /api/users | token | USUARIOS | `?buscar=` → `[Usuario]` |
| GET | /api/users/{id} | token | USUARIOS | `Usuario`; 404 |
| POST | /api/users | token | USUARIOS | in `{ nombre, usuario, correo, clave, activo }` → 201 + header Location + `Usuario`; 400 (nombre 3-120, usuario 3-50 `^[a-z0-9._-]+$`, correo válido, clave ≥8 con mayúscula, minúscula, número y símbolo); 409 `USUARIO_DUPLICADO`/`CORREO_DUPLICADO` |
| PATCH | /api/users/{id}/estado | token | USUARIOS | in `{ activo: bool }` → 200 `Usuario`; 409 si intenta inactivarse a sí mismo |
| GET | /api/menus | token | ASIGNACION | `[Menu]` con `totalUsuarios` (catálogo activo) |
| GET | /api/users/{id}/menus | token | ASIGNACION (o el propio usuario consultando su id) | `[Menu]` |
| PUT | /api/users/{id}/menus | token | ASIGNACION | in `{ menuIds:[1,2,3] }` → 200 `{ agregados, retirados, menus:[Menu] }`; 400 ids inexistentes; 404 usuario; 409 `AUTOBLOQUEO` si se quita ASIGNACION a sí mismo |
| GET | /api/tablero | token | TABLERO | `{ kpis:{...}, serie:[{dia,loginsOk,loginsFallidos,accesosDenegados}], usoMenus:[{codigo,nombre,totalUsuarios}], matriz:[{idUsuario,usuario,codigo}] }` |
| GET | /api/auditoria | token | AUDITORIA | `?evento=&limite=200` → `[Evento]` |
| GET | /api/clientes | token | CLIENTES | `[Cliente]` |
| GET | /api/polizas | token | POLIZAS | `[Poliza]` |
| GET | /api/siniestros | token | SINIESTROS | `[Siniestro]` |

Modelos JSON:
- `Usuario`: `{ id, nombre, usuario, correo, activo, ultimoAcceso, fechaCreacion, totalMenus }`
- `Menu`: `{ id, codigo, nombre, descripcion, ruta, icono, grupo, orden, totalUsuarios? , fechaAsignacion? }`
- `Evento`: `{ id, fecha, idUsuario, usuario, evento, recurso, ip, detalle }`
- `Cliente`: `{ id, nit, razonSocial, sector, ciudad, fechaAlta, polizasVigentes }`
- `Poliza`: `{ id, numero, cliente, ramo, aseguradora, prima, vigenciaDesde, vigenciaHasta, estado, diasParaVencer }`
- `Siniestro`: `{ id, numero, poliza, cliente, fechaAviso, descripcion, valorReclamado, estado }`
- `kpis`: `{ usuariosTotal, usuariosActivos, menusActivos, asignacionesTotal, loginsHoy, denegados7d, fallidos7d, bloqueadosAhora }`

## Front (rutas hash en `index.html`)
- `login.html`: login de dos paneles (estilo referencia). Guarda token en `sessionStorage` (`atalaya.token`) y redirige a `index.html`.
- `index.html`: shell (barra superior + barra lateral clara colapsable a riel de íconos + contenido). Al cargar llama `GET /api/auth/yo`; la barra lateral se arma SOLO con esos menús, agrupados por `grupo` y ordenados por `orden`. Buscador de menú.
- Rutas: `#/inicio` (bienvenida, siempre), `#/tablero`, `#/usuarios`, `#/asignacion`, `#/auditoria`, `#/clientes`, `#/polizas`, `#/siniestros`, `#/manual` (siempre, ícono de ayuda en la barra superior), `#/sin-acceso`.
- Guardia del front: si la ruta no está entre los menús del usuario → pantalla "Sin acceso" que ADEMÁS muestra la respuesta 403 real de la API (llama al endpoint de ese módulo y enseña estado + JSON). Es la prueba visual de que la seguridad está en el backend.
- 401 en cualquier llamada → limpiar sesión y volver a `login.html`.
- Valores en pesos: entero con punto de miles fijo (`150.000`), sin depender de la configuración regional.
