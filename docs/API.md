# Atalaya — API REST

Base local: `http://localhost:52080` (IIS Express, puerto fijo). Todo el JSON va en **camelCase**, las fechas en **ISO 8601** y los valores en pesos como **enteros**.

- Swagger UI: `http://localhost:52080/swagger`
- Documento Swagger 2.0: `http://localhost:52080/swagger/docs/v1`
- Colección Postman: [`Atalaya.postman_collection.json`](Atalaya.postman_collection.json)

## Autenticación y autorización

1. `POST /api/auth/login` con usuario **o** correo y clave → devuelve un JWT (HS256, emisor `Atalaya`, 8 horas).
2. Se envía en cada petición: `Authorization: Bearer <token>`.
3. Cada endpoint protegido exige un **menú** (`[RequiereMenu("CODIGO")]`). El permiso se consulta en la BD (`sp_usuario_tiene_menu`) **en cada petición**: si a un usuario se le quita un menú o se inactiva, pierde el acceso de inmediato aunque su token siga vigente.
4. Sin token, o con token vencido/inválido → **401**. Con token pero sin el menú → **403** (y queda `ACCESO_DENEGADO` en la bitácora con la IP).

Claims del token: `sub` (id del usuario), `unique_name` (usuario), `name` (nombre), `jti`, `nbf`, `exp`, `iss`, `aud`.

### Usar Swagger con el token

1. Abra `/swagger`, despliegue **Auth → POST /api/auth/login**, pulse *Try it out* y envíe `{ "login": "admin", "clave": "Admin#2026" }`.
2. Copie el valor de `token` de la respuesta.
3. En la parte superior de la página, en el campo **api_key**, pegue `Bearer <token>` (con la palabra `Bearer` y un espacio) y pulse *Explore*.
4. Desde ese momento todas las peticiones de prueba llevan el encabezado `Authorization`.

## Endpoints

| Método | Ruta | Auth | Menú | Éxito | Errores |
|---|---|---|---|---|---|
| GET | `/api/salud` | anónimo | — | 200 | 503 si la BD no responde |
| POST | `/api/auth/login` | anónimo | — | 200 | 400, 401 `CREDENCIALES_INVALIDAS`, 403 `USUARIO_INACTIVO`, 423 `USUARIO_BLOQUEADO` |
| GET | `/api/auth/yo` | token | — | 200 | 401 |
| GET | `/api/users?buscar=` | token | USUARIOS | 200 | 401, 403 |
| GET | `/api/users/{id}` | token | USUARIOS | 200 | 401, 403, 404 |
| POST | `/api/users` | token | USUARIOS | 201 + `Location` | 400, 401, 403, 409 `USUARIO_DUPLICADO` / `CORREO_DUPLICADO` |
| PATCH | `/api/users/{id}/estado` | token | USUARIOS | 200 | 400, 401, 403, 404, 409 `AUTOINACTIVACION` |
| GET | `/api/menus` | token | ASIGNACION | 200 | 401, 403 |
| GET | `/api/users/{id}/menus` | token | ASIGNACION o el propio usuario | 200 | 401, 403, 404 |
| PUT | `/api/users/{id}/menus` | token | ASIGNACION | 200 | 400 `MENUS_INEXISTENTES`, 401, 403, 404, 409 `AUTOBLOQUEO` |
| GET | `/api/tablero` | token | TABLERO | 200 | 401, 403 |
| GET | `/api/auditoria?evento=&limite=200` | token | AUDITORIA | 200 | 400, 401, 403 |
| GET | `/api/clientes` | token | CLIENTES | 200 | 401, 403 |
| GET | `/api/polizas` | token | POLIZAS | 200 | 401, 403 |
| GET | `/api/siniestros` | token | SINIESTROS | 200 | 401, 403 |

Cualquier otra ruta bajo `/api/` responde 404 `RECURSO_NO_ENCONTRADO`; un verbo no soportado responde 405 `METODO_NO_PERMITIDO`.

## Formato de error (único para toda la API)

```json
{ "estado": 403, "codigo": "ACCESO_DENEGADO", "mensaje": "No tiene autorización para el menú USUARIOS.", "detalles": null, "traza": "390640d5f17441f4" }
```

- `detalles`: solo en 400, diccionario `campo → mensaje`.
- `traza`: identificador que también queda en el log del servidor (en los 500 junto con la excepción completa). El cliente nunca recibe stack traces.

| HTTP | Códigos |
|---|---|
| 400 | `VALIDACION`, `MENUS_INEXISTENTES` |
| 401 | `NO_AUTENTICADO`, `TOKEN_INVALIDO`, `TOKEN_EXPIRADO`, `CREDENCIALES_INVALIDAS`, `SESION_INVALIDA` |
| 403 | `ACCESO_DENEGADO`, `USUARIO_INACTIVO` |
| 404 | `USUARIO_NO_ENCONTRADO`, `RECURSO_NO_ENCONTRADO` |
| 405 | `METODO_NO_PERMITIDO` |
| 409 | `USUARIO_DUPLICADO`, `CORREO_DUPLICADO`, `AUTOINACTIVACION`, `AUTOBLOQUEO` |
| 415 | `TIPO_CONTENIDO_NO_SOPORTADO` |
| 423 | `USUARIO_BLOQUEADO` |
| 500 | `ERROR_INTERNO` |
| 503 | (salud) `{ "estado": "degradado", "baseDatos": "error" }` |

## Reglas del login

- Acepta usuario **o** correo.
- Usuario inexistente y clave equivocada dan **la misma** respuesta (401 `CREDENCIALES_INVALIDAS`) y tardan lo mismo (se ejecuta un PBKDF2 de relleno), para no revelar qué usuarios existen.
- Si la cuenta está bloqueada se responde 423 **sin comparar la clave**. 5 fallos seguidos → bloqueo de 15 minutos (regla en `sp_usuario_registrar_login`). El quinto fallo ya responde 423.
- El estado inactivo (403) solo se informa cuando la clave es correcta.
- Bitácora: `LOGIN_OK`, `LOGIN_FALLIDO`, `LOGIN_BLOQUEADO`, todos con IP.

## Ejemplos

### Login

```http
POST /api/auth/login
Content-Type: application/json

{ "login": "admin", "clave": "Admin#2026" }
```

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiraEn": "2026-10-20T00:36:32.445092Z",
  "usuario": { "id": 1, "nombre": "Administrador Atalaya", "usuario": "admin", "correo": "admin@atalaya.test" },
  "menus": [
    { "id": 1, "codigo": "TABLERO", "nombre": "Tablero", "descripcion": "...", "ruta": "#/tablero",
      "icono": "speedometer2", "grupo": "Control", "orden": 1, "fechaAsignacion": "2026-10-05T07:31:00" }
  ]
}
```

Cuenta bloqueada:

```json
{ "estado": 423, "codigo": "USUARIO_BLOQUEADO", "mensaje": "La cuenta está bloqueada por intentos fallidos. Intente de nuevo en 15 minutos.", "detalles": null, "traza": "26b64b42b..." }
```

### Crear usuario

```http
POST /api/users
Authorization: Bearer <token>
Content-Type: application/json

{ "nombre": "Prueba API", "usuario": "prueba.api", "correo": "prueba.api@atalaya.test", "clave": "Prueba#2026", "activo": true }
```

`201 Created`, `Location: http://localhost:52080/api/users/5`

```json
{ "id": 5, "nombre": "Prueba API", "usuario": "prueba.api", "correo": "prueba.api@atalaya.test", "activo": true, "ultimoAcceso": null, "fechaCreacion": "2026-10-19T11:37:05", "totalMenus": 0 }
```

Reglas: nombre 3-120; usuario 3-50 con `^[a-z0-9._-]+$`; correo válido (máx. 150); clave ≥ 8 con mayúscula, minúscula, número y símbolo; `activo` es `true` si no se envía.

Validación fallida (400):

```json
{
  "estado": 400, "codigo": "VALIDACION", "mensaje": "La solicitud tiene datos inválidos.",
  "detalles": {
    "nombre": "El nombre debe tener entre 3 y 120 caracteres.",
    "usuario": "El usuario solo admite minúsculas, números, punto, guion y guion bajo.",
    "correo": "El correo no tiene un formato válido.",
    "clave": "La clave debe tener entre 8 y 128 caracteres."
  },
  "traza": "51cd1c11532a4451"
}
```

### Cambiar estado

```http
PATCH /api/users/5/estado
{ "activo": false }
```

→ 200 con el `Usuario` actualizado. Inactivarse a sí mismo → 409 `AUTOINACTIVACION`.

### Asignar menús (reemplazo completo)

```http
PUT /api/users/5/menus
{ "menuIds": [5, 6] }
```

```json
{ "agregados": 2, "retirados": 0, "menus": [ { "id": 5, "codigo": "CLIENTES", "...": "..." }, { "id": 6, "codigo": "POLIZAS", "...": "..." } ] }
```

- Ids inexistentes o inactivos → 400 `MENUS_INEXISTENTES` con `detalles.menuIds`.
- Quitarse a sí mismo ASIGNACION → 409 `AUTOBLOQUEO`.
- `[]` retira todos los menús.

### Analista intentando gestionar usuarios (prueba de seguridad en backend)

```http
GET /api/users
Authorization: Bearer <token del analista>
```

```json
{ "estado": 403, "codigo": "ACCESO_DENEGADO", "mensaje": "No tiene autorización para el menú USUARIOS.", "detalles": null, "traza": "390640d5f17441f4" }
```

Y en `/api/auditoria?evento=ACCESO_DENEGADO`:

```json
{ "id": 114, "fecha": "2026-10-19T11:37:31", "idUsuario": 2, "usuario": "analista", "evento": "ACCESO_DENEGADO", "recurso": "GET /api/users", "ip": "::1", "detalle": "Menú requerido: USUARIOS" }
```

### Tablero

```json
{
  "kpis": { "usuariosTotal": 5, "usuariosActivos": 4, "menusActivos": 7, "asignacionesTotal": 15, "loginsHoy": 12, "denegados7d": 11, "fallidos7d": 19, "bloqueadosAhora": 0 },
  "serie": [ { "dia": "2026-10-06T00:00:00", "loginsOk": 6, "loginsFallidos": 4, "accesosDenegados": 2 } ],
  "usoMenus": [ { "codigo": "TABLERO", "nombre": "Tablero", "totalUsuarios": 2 } ],
  "matriz": [ { "idUsuario": 1, "usuario": "admin", "codigo": "TABLERO" } ]
}
```

## Encabezados de seguridad

Todas las respuestas llevan `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` y `Referrer-Policy: strict-origin-when-cross-origin`; se eliminan `X-Powered-By`, `X-AspNet-Version` y `Server`. Las respuestas de la API llevan `Cache-Control: no-store, no-cache`.

## Configuración local

- `src/Atalaya.Web/ConnectionStrings.config` (copiar de `ConnectionStrings.example.config`): cadena `Atalaya`.
- `src/Atalaya.Web/Secretos.config` (copiar de `Secretos.example.config`): `Jwt:Clave` aleatoria de 32+ caracteres. Si falta, el sitio no arranca y el error indica qué archivo completar.
- Ambos están en `.gitignore`.
