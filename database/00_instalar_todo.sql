-- =============================================================================
-- Atalaya - Control de acceso por menús
-- 01_esquema.sql : base de datos, tablas, llaves, índices.
-- Motor: MySQL 8.x  |  Juego de caracteres: utf8mb4 / utf8mb4_unicode_ci
--
-- utf8mb4 soporta todo Unicode (tildes, eñes, emojis) y la intercalación
-- unicode_ci compara sin distinguir mayúsculas: 'Admin' y 'admin' chocan en
-- los índices UNIQUE, que es lo que queremos para usuario y correo.
-- Todas las tablas son InnoDB: transacciones (ACID) y llaves foráneas reales.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS atalaya_acceso
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE atalaya_acceso;

-- Se eliminan en orden inverso a las dependencias (hijas primero) para que
-- las llaves foráneas no impidan el DROP. El script es re-ejecutable.
DROP TABLE IF EXISTS siniestro;
DROP TABLE IF EXISTS poliza;
DROP TABLE IF EXISTS cliente;
DROP TABLE IF EXISTS bitacora_acceso;
DROP TABLE IF EXISTS usuario_menu;
DROP TABLE IF EXISTS menu;
DROP TABLE IF EXISTS usuario;

-- -----------------------------------------------------------------------------
-- usuario: personas que ingresan al sistema.
-- * La clave NUNCA se guarda: se guarda hash PBKDF2-SHA256 + sal (Base64).
-- * iteraciones va en columna propia: si mañana se sube el costo (p. ej. a
--   210000) los usuarios viejos siguen validando con su número original y se
--   pueden re-hashear en su próximo login, sin migración masiva.
-- * intentos_fallidos / bloqueado_hasta implementan el bloqueo temporal
--   (5 fallos seguidos -> 15 minutos) contra fuerza bruta.
-- * creado_por es auto-referencia (quién creó el usuario) para trazabilidad.
-- -----------------------------------------------------------------------------
CREATE TABLE usuario (
  id_usuario        INT           NOT NULL AUTO_INCREMENT,
  nombre            VARCHAR(120)  NOT NULL,
  usuario           VARCHAR(50)   NOT NULL,
  correo            VARCHAR(150)  NOT NULL,
  hash_clave        VARCHAR(255)  NOT NULL,
  sal_clave         VARCHAR(255)  NOT NULL,
  iteraciones       INT           NOT NULL DEFAULT 100000,
  estado            TINYINT(1)    NOT NULL DEFAULT 1 COMMENT '1 activo, 0 inactivo',
  intentos_fallidos INT           NOT NULL DEFAULT 0,
  bloqueado_hasta   DATETIME      NULL,
  ultimo_acceso     DATETIME      NULL,
  fecha_creacion    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  creado_por        INT           NULL,
  PRIMARY KEY (id_usuario),
  -- UNIQUE: garantiza en la BD (no solo en el API) que no haya duplicados,
  -- incluso con dos peticiones simultáneas. Además sirven de índice para el
  -- login, que busca por usuario O por correo.
  UNIQUE KEY uq_usuario_usuario (usuario),
  UNIQUE KEY uq_usuario_correo (correo),
  -- Índice para los conteos del tablero (usuarios activos / bloqueados).
  KEY ix_usuario_estado (estado),
  -- Si se borrara el creador, el usuario creado no se pierde: queda en NULL.
  CONSTRAINT fk_usuario_creado_por FOREIGN KEY (creado_por)
    REFERENCES usuario (id_usuario) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Usuarios del sistema con clave PBKDF2 y bloqueo temporal';

-- -----------------------------------------------------------------------------
-- menu: catálogo de opciones del sistema. El "codigo" (USUARIOS, POLIZAS...)
-- es el identificador funcional que usa el backend en [RequiereMenu("...")],
-- así el código fuente no depende de ids autoincrementales.
-- ruta/icono/grupo/orden permiten que el front arme la barra lateral desde
-- datos (menú dinámico) sin cambiar código.
-- -----------------------------------------------------------------------------
CREATE TABLE menu (
  id_menu        INT          NOT NULL AUTO_INCREMENT,
  codigo         VARCHAR(40)  NOT NULL,
  nombre         VARCHAR(80)  NOT NULL,
  descripcion    VARCHAR(255) NOT NULL,
  ruta           VARCHAR(120) NOT NULL,
  icono          VARCHAR(60)  NOT NULL COMMENT 'Clase Bootstrap Icons sin prefijo bi-',
  grupo          VARCHAR(40)  NOT NULL COMMENT 'Gestión, Operación, Control',
  orden          INT          NOT NULL DEFAULT 0,
  estado         TINYINT(1)   NOT NULL DEFAULT 1,
  fecha_creacion DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_menu),
  UNIQUE KEY uq_menu_codigo (codigo),
  -- Índice compuesto para "menús activos ordenados", la consulta más común.
  KEY ix_menu_estado_orden (estado, orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Catálogo de menús / módulos protegidos';

-- -----------------------------------------------------------------------------
-- usuario_menu: tabla puente de la relación muchos-a-muchos usuario <-> menú.
-- * Un usuario tiene varios menús y un menú lo tienen varios usuarios: la
--   forma normalizada (3FN) es una tabla intermedia, no una columna con CSV.
-- * PK compuesta (id_usuario, id_menu): impide asignar dos veces el mismo
--   menú y sirve de índice para "menús de un usuario" y para la verificación
--   de permiso que el API hace en CADA petición.
-- * Índice adicional por id_menu para "usuarios de un menú" (conteos).
-- * ON DELETE CASCADE: si se elimina un usuario o un menú, sus asignaciones
--   desaparecen solas (no quedan permisos huérfanos).
-- * fecha_asignacion / asignado_por: trazabilidad de quién dio el permiso.
-- -----------------------------------------------------------------------------
CREATE TABLE usuario_menu (
  id_usuario       INT      NOT NULL,
  id_menu          INT      NOT NULL,
  fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  asignado_por     INT      NULL,
  PRIMARY KEY (id_usuario, id_menu),
  KEY ix_usuario_menu_menu (id_menu),
  KEY ix_usuario_menu_asignado_por (asignado_por),
  CONSTRAINT fk_usuario_menu_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario (id_usuario) ON DELETE CASCADE,
  CONSTRAINT fk_usuario_menu_menu FOREIGN KEY (id_menu)
    REFERENCES menu (id_menu) ON DELETE CASCADE,
  CONSTRAINT fk_usuario_menu_asignado_por FOREIGN KEY (asignado_por)
    REFERENCES usuario (id_usuario) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Asignación de menús a usuarios (muchos a muchos)';

-- -----------------------------------------------------------------------------
-- bitacora_acceso: auditoría de seguridad (solo inserción, nunca se edita).
-- Eventos: LOGIN_OK, LOGIN_FALLIDO, LOGIN_BLOQUEADO, ACCESO_DENEGADO,
--          USUARIO_CREADO, USUARIO_ESTADO, MENUS_ACTUALIZADOS.
-- * BIGINT porque es la tabla que más crece.
-- * id_usuario SIN llave foránea a propósito: la bitácora debe aceptar
--   cualquier evento (p. ej. login fallido de un usuario que no existe) y no
--   puede fallar ni perderse si un usuario se borra. Por eso también se guarda
--   usuario_texto (lo que se digitó / el nombre al momento del evento).
-- * ip VARCHAR(45): cabe una IPv6 completa.
-- -----------------------------------------------------------------------------
CREATE TABLE bitacora_acceso (
  id_bitacora   BIGINT       NOT NULL AUTO_INCREMENT,
  fecha         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_usuario    INT          NULL,
  usuario_texto VARCHAR(50)  NULL,
  evento        VARCHAR(30)  NOT NULL,
  recurso       VARCHAR(150) NULL,
  ip            VARCHAR(45)  NULL,
  detalle       VARCHAR(255) NULL,
  PRIMARY KEY (id_bitacora),
  -- Listado cronológico y series por rango de fechas del tablero.
  KEY ix_bitacora_fecha (fecha),
  -- Filtro por tipo de evento + rango de fechas (KPIs "fallidos 7 días",
  -- "denegados 7 días" y el filtro de la pantalla de auditoría).
  KEY ix_bitacora_evento_fecha (evento, fecha),
  -- Historial de un usuario puntual.
  KEY ix_bitacora_usuario_fecha (id_usuario, fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Bitácora de accesos y cambios de seguridad (append-only)';

-- =============================================================================
-- Datos de negocio de demostración (broker de seguros, todo ficticio).
-- Existen para que cada menú proteja algo real y se vea la autorización.
-- =============================================================================

-- cliente: empresas tomadoras de pólizas.
CREATE TABLE cliente (
  id_cliente   INT          NOT NULL AUTO_INCREMENT,
  nit          VARCHAR(20)  NOT NULL,
  razon_social VARCHAR(150) NOT NULL,
  sector       VARCHAR(60)  NOT NULL,
  ciudad       VARCHAR(60)  NOT NULL,
  fecha_alta   DATE         NOT NULL,
  PRIMARY KEY (id_cliente),
  UNIQUE KEY uq_cliente_nit (nit)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Clientes (tomadores) del broker - datos ficticios';

-- poliza: contratos de seguro de cada cliente.
-- prima DECIMAL(14,0): pesos colombianos sin decimales (nunca FLOAT para dinero).
-- estado: VIGENTE | POR_RENOVAR | VENCIDA (el SP de listado lo recalcula
-- contra la fecha actual para que nunca quede desactualizado).
CREATE TABLE poliza (
  id_poliza      INT           NOT NULL AUTO_INCREMENT,
  numero         VARCHAR(30)   NOT NULL,
  id_cliente     INT           NOT NULL,
  ramo           VARCHAR(80)   NOT NULL,
  aseguradora    VARCHAR(80)   NOT NULL,
  prima          DECIMAL(14,0) NOT NULL,
  vigencia_desde DATE          NOT NULL,
  vigencia_hasta DATE          NOT NULL,
  estado         VARCHAR(20)   NOT NULL DEFAULT 'VIGENTE',
  PRIMARY KEY (id_poliza),
  UNIQUE KEY uq_poliza_numero (numero),
  KEY ix_poliza_cliente (id_cliente),
  -- Pólizas próximas a vencer (orden del listado y conteo de vigentes).
  KEY ix_poliza_vigencia_hasta (vigencia_hasta),
  CONSTRAINT fk_poliza_cliente FOREIGN KEY (id_cliente)
    REFERENCES cliente (id_cliente) ON DELETE RESTRICT,
  CONSTRAINT ck_poliza_estado CHECK (estado IN ('VIGENTE','POR_RENOVAR','VENCIDA')),
  CONSTRAINT ck_poliza_vigencia CHECK (vigencia_hasta >= vigencia_desde)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Pólizas de seguro - datos ficticios';

-- siniestro: reclamaciones sobre una póliza.
CREATE TABLE siniestro (
  id_siniestro    INT           NOT NULL AUTO_INCREMENT,
  numero          VARCHAR(30)   NOT NULL,
  id_poliza       INT           NOT NULL,
  fecha_aviso     DATE          NOT NULL,
  descripcion     VARCHAR(255)  NOT NULL,
  valor_reclamado DECIMAL(14,0) NOT NULL,
  estado          VARCHAR(20)   NOT NULL DEFAULT 'ABIERTO',
  PRIMARY KEY (id_siniestro),
  UNIQUE KEY uq_siniestro_numero (numero),
  KEY ix_siniestro_poliza (id_poliza),
  KEY ix_siniestro_fecha_aviso (fecha_aviso),
  CONSTRAINT fk_siniestro_poliza FOREIGN KEY (id_poliza)
    REFERENCES poliza (id_poliza) ON DELETE RESTRICT,
  CONSTRAINT ck_siniestro_estado CHECK (estado IN ('ABIERTO','EN_AJUSTE','PAGADO','OBJETADO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Siniestros reclamados - datos ficticios';

-- =============================================================================
-- Atalaya - 02_procedimientos.sql : procedimientos almacenados (SPs).
--
-- Por qué SPs: el API NUNCA arma SQL concatenando texto; solo invoca SPs con
-- parámetros tipados (p_*). Eso elimina la inyección SQL, deja la lógica de
-- datos en un solo lugar y permite dar al usuario de la aplicación solo el
-- permiso EXECUTE (no SELECT/UPDATE libres sobre las tablas).
--
-- Convenciones: parámetros p_*, variables locales v_*, columnas de salida en
-- snake_case exactamente como dice docs/CONTRATO.md.
-- =============================================================================

USE atalaya_acceso;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- sp_usuario_crear: inserta un usuario. El hash/sal ya vienen calculados por
-- el API (la clave en claro nunca llega a la BD).
-- Valida duplicados con mensajes de negocio (USUARIO_DUPLICADO /
-- CORREO_DUPLICADO) que el API traduce a HTTP 409. Además, si dos peticiones
-- simultáneas pasan la validación, el índice UNIQUE dispara el error 1062 y
-- el manejador lo convierte al mismo mensaje de negocio.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_crear $$
CREATE PROCEDURE sp_usuario_crear(
  IN p_nombre      VARCHAR(120),
  IN p_usuario     VARCHAR(50),
  IN p_correo      VARCHAR(150),
  IN p_hash_clave  VARCHAR(255),
  IN p_sal_clave   VARCHAR(255),
  IN p_iteraciones INT,
  IN p_estado      TINYINT,
  IN p_creado_por  INT
)
BEGIN
  DECLARE EXIT HANDLER FOR 1062
  BEGIN
    IF EXISTS (SELECT 1 FROM usuario WHERE correo = p_correo) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CORREO_DUPLICADO';
    ELSE
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USUARIO_DUPLICADO';
    END IF;
  END;

  IF EXISTS (SELECT 1 FROM usuario WHERE usuario = p_usuario) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USUARIO_DUPLICADO';
  END IF;
  IF EXISTS (SELECT 1 FROM usuario WHERE correo = p_correo) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CORREO_DUPLICADO';
  END IF;

  INSERT INTO usuario (nombre, usuario, correo, hash_clave, sal_clave,
                       iteraciones, estado, creado_por)
  VALUES (p_nombre, p_usuario, p_correo, p_hash_clave, p_sal_clave,
          COALESCE(p_iteraciones, 100000), COALESCE(p_estado, 1), p_creado_por);

  SELECT LAST_INSERT_ID() AS id_usuario;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_listar: listado con búsqueda opcional (NULL o vacío = todos) en
-- nombre, usuario o correo. total_menus = menús ACTIVOS asignados.
-- Nunca devuelve hash ni sal.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_listar $$
CREATE PROCEDURE sp_usuario_listar(IN p_buscar VARCHAR(500))
BEGIN
  DECLARE v_patron VARCHAR(510);
  SET v_patron = CONCAT('%', TRIM(COALESCE(p_buscar, '')), '%');

  SELECT u.id_usuario, u.nombre, u.usuario, u.correo, u.estado,
         u.ultimo_acceso, u.fecha_creacion,
         (SELECT COUNT(*) FROM usuario_menu um
            JOIN menu m ON m.id_menu = um.id_menu AND m.estado = 1
           WHERE um.id_usuario = u.id_usuario) AS total_menus
    FROM usuario u
   WHERE p_buscar IS NULL OR TRIM(p_buscar) = ''
      OR u.nombre  LIKE v_patron
      OR u.usuario LIKE v_patron
      OR u.correo  LIKE v_patron
   ORDER BY u.nombre;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_obtener: un usuario por id (mismas columnas que el listado).
-- Si no existe devuelve 0 filas y el API responde 404.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_obtener $$
CREATE PROCEDURE sp_usuario_obtener(IN p_id_usuario INT)
BEGIN
  SELECT u.id_usuario, u.nombre, u.usuario, u.correo, u.estado,
         u.ultimo_acceso, u.fecha_creacion,
         (SELECT COUNT(*) FROM usuario_menu um
            JOIN menu m ON m.id_menu = um.id_menu AND m.estado = 1
           WHERE um.id_usuario = u.id_usuario) AS total_menus
    FROM usuario u
   WHERE u.id_usuario = p_id_usuario;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_obtener_para_login: único SP que devuelve hash/sal/iteraciones.
-- Acepta usuario O correo (ambos tienen índice UNIQUE). La verificación de la
-- clave se hace en el API (PBKDF2 + comparación en tiempo constante).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_obtener_para_login $$
CREATE PROCEDURE sp_usuario_obtener_para_login(IN p_login VARCHAR(500))
BEGIN
  SELECT id_usuario, nombre, usuario, correo, hash_clave, sal_clave,
         iteraciones, estado, intentos_fallidos, bloqueado_hasta
    FROM usuario
   WHERE usuario = TRIM(p_login) OR correo = TRIM(p_login)
   LIMIT 1;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_registrar_login: aplica la política de bloqueo.
-- * Éxito: intentos_fallidos = 0, quita el bloqueo, ultimo_acceso = NOW().
-- * Fallo: si había un bloqueo ya vencido, el contador arranca de cero;
--   suma 1 y, al llegar a 5 fallos seguidos, bloquea 15 minutos.
--   Un fallo durante un bloqueo vigente no lo extiende.
-- p_ip se recibe por contrato (el evento en bitácora lo registra el API con
-- sp_bitacora_registrar, que sabe el tipo exacto de evento).
-- Devuelve el estado resultante: intentos_fallidos, bloqueado_hasta.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_registrar_login $$
CREATE PROCEDURE sp_usuario_registrar_login(
  IN p_id_usuario INT,
  IN p_exitoso    TINYINT,
  IN p_ip         VARCHAR(45)
)
BEGIN
  IF p_exitoso = 1 THEN
    UPDATE usuario
       SET intentos_fallidos = 0,
           bloqueado_hasta   = NULL,
           ultimo_acceso     = NOW()
     WHERE id_usuario = p_id_usuario;
  ELSE
    -- 1) Bloqueo anterior ya vencido: se reinicia el conteo.
    UPDATE usuario
       SET intentos_fallidos = 0,
           bloqueado_hasta   = NULL
     WHERE id_usuario = p_id_usuario
       AND bloqueado_hasta IS NOT NULL
       AND bloqueado_hasta <= NOW();

    -- 2) Se cuenta el fallo.
    UPDATE usuario
       SET intentos_fallidos = intentos_fallidos + 1
     WHERE id_usuario = p_id_usuario;

    -- 3) Quinto fallo seguido (y sin bloqueo vigente): bloquear 15 minutos.
    UPDATE usuario
       SET bloqueado_hasta = NOW() + INTERVAL 15 MINUTE
     WHERE id_usuario = p_id_usuario
       AND intentos_fallidos >= 5
       AND bloqueado_hasta IS NULL;
  END IF;

  SELECT intentos_fallidos, bloqueado_hasta
    FROM usuario
   WHERE id_usuario = p_id_usuario;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_cambiar_estado: activa (1) / inactiva (0).
-- filas_afectadas = 1 si el usuario existe (aunque ya tuviera ese estado),
-- 0 si no existe -> el API responde 404. Se calcula con COUNT y no con
-- ROW_COUNT() porque éste devuelve 0 cuando el valor no cambia.
-- Al activar se limpia también el bloqueo por intentos.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_cambiar_estado $$
CREATE PROCEDURE sp_usuario_cambiar_estado(
  IN p_id_usuario INT,
  IN p_estado     TINYINT
)
BEGIN
  UPDATE usuario
     SET estado            = IF(p_estado = 1, 1, 0),
         intentos_fallidos = IF(p_estado = 1, 0, intentos_fallidos),
         bloqueado_hasta   = IF(p_estado = 1, NULL, bloqueado_hasta)
   WHERE id_usuario = p_id_usuario;

  SELECT COUNT(*) AS filas_afectadas
    FROM usuario
   WHERE id_usuario = p_id_usuario;
END $$

-- -----------------------------------------------------------------------------
-- sp_menu_listar: catálogo de menús con cuántos usuarios lo tienen asignado.
-- p_solo_activos = 1 -> solo estado 1; 0 o NULL -> todos.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_menu_listar $$
CREATE PROCEDURE sp_menu_listar(IN p_solo_activos TINYINT)
BEGIN
  SELECT m.id_menu, m.codigo, m.nombre, m.descripcion, m.ruta, m.icono,
         m.grupo, m.orden, m.estado,
         (SELECT COUNT(*) FROM usuario_menu um
           WHERE um.id_menu = m.id_menu) AS total_usuarios
    FROM menu m
   WHERE COALESCE(p_solo_activos, 0) = 0 OR m.estado = 1
   ORDER BY m.orden, m.nombre;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_menus_listar: menús ACTIVOS asignados a un usuario. Es la fuente
-- del menú dinámico del front (GET /api/auth/yo) y de la pantalla de
-- asignación. Usa la PK (id_usuario, id_menu) de la tabla puente.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_menus_listar $$
CREATE PROCEDURE sp_usuario_menus_listar(IN p_id_usuario INT)
BEGIN
  SELECT m.id_menu, m.codigo, m.nombre, m.descripcion, m.ruta, m.icono,
         m.grupo, m.orden, um.fecha_asignacion
    FROM usuario_menu um
    JOIN menu m ON m.id_menu = um.id_menu
   WHERE um.id_usuario = p_id_usuario
     AND m.estado = 1
   ORDER BY m.orden;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_menus_reemplazar: deja al usuario EXACTAMENTE con los menús del
-- CSV p_ids_menu ("1,3,5"; vacío o NULL = quitar todos).
-- * Todo en una transacción: o se aplica completo o nada (si algo falla se
--   hace ROLLBACK y se relanza el error al API con RESIGNAL).
-- * Solo borra lo que sobra y solo inserta lo que falta, así se conserva la
--   fecha_asignacion original de los menús que se mantienen.
-- * FIND_IN_SET contra menu.id_menu: solo se insertan ids que EXISTEN en el
--   catálogo (el API ya valida, esto es defensa en profundidad). Con 7 menús
--   el recorrido completo de la tabla es despreciable.
-- Devuelve: agregados, retirados.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_menus_reemplazar $$
CREATE PROCEDURE sp_usuario_menus_reemplazar(
  IN p_id_usuario   INT,
  IN p_ids_menu     VARCHAR(1000),
  IN p_asignado_por INT
)
BEGIN
  DECLARE v_csv       VARCHAR(1000);
  DECLARE v_retirados INT DEFAULT 0;
  DECLARE v_agregados INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  -- Normaliza: sin espacios ni comas sobrantes. NULL se trata como vacío.
  SET v_csv = TRIM(BOTH ',' FROM REPLACE(COALESCE(p_ids_menu, ''), ' ', ''));

  START TRANSACTION;

  -- 1) Retirar lo que ya no viene en la lista.
  DELETE FROM usuario_menu
   WHERE id_usuario = p_id_usuario
     AND FIND_IN_SET(id_menu, v_csv) = 0;
  SET v_retirados = ROW_COUNT();

  -- 2) Agregar lo nuevo (solo menús existentes y aún no asignados).
  INSERT INTO usuario_menu (id_usuario, id_menu, fecha_asignacion, asignado_por)
  SELECT p_id_usuario, m.id_menu, NOW(), p_asignado_por
    FROM menu m
   WHERE FIND_IN_SET(m.id_menu, v_csv) > 0
     AND NOT EXISTS (SELECT 1 FROM usuario_menu um
                      WHERE um.id_usuario = p_id_usuario
                        AND um.id_menu = m.id_menu);
  SET v_agregados = ROW_COUNT();

  COMMIT;

  SELECT v_agregados AS agregados, v_retirados AS retirados;
END $$

-- -----------------------------------------------------------------------------
-- sp_usuario_tiene_menu: la pregunta de autorización que el API hace en CADA
-- petición protegida ([RequiereMenu("CODIGO")]). Autoriza solo si:
-- usuario activo + menú activo + asignación existente.
-- Como se consulta en vivo (no se confía en el token), quitar un menú o
-- inactivar al usuario corta el acceso de inmediato.
-- Costo: búsquedas por PK/UNIQUE, una sola fila.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_usuario_tiene_menu $$
CREATE PROCEDURE sp_usuario_tiene_menu(
  IN p_id_usuario  INT,
  IN p_codigo_menu VARCHAR(40)
)
BEGIN
  SELECT EXISTS (
           SELECT 1
             FROM usuario u
             JOIN usuario_menu um ON um.id_usuario = u.id_usuario
             JOIN menu m          ON m.id_menu = um.id_menu
            WHERE u.id_usuario = p_id_usuario
              AND u.estado = 1
              AND m.codigo = p_codigo_menu
              AND m.estado = 1
         ) AS autorizado;
END $$

-- -----------------------------------------------------------------------------
-- sp_bitacora_registrar: agrega un evento de auditoría. Recorta los textos al
-- tamaño de la columna para que un dato largo (p. ej. un User-Agent en el
-- detalle) nunca haga fallar la operación principal. Por eso los parámetros
-- son más anchos que las columnas: en modo estricto MySQL rechazaría un
-- parámetro demasiado largo ANTES de que LEFT() alcance a recortarlo.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_bitacora_registrar $$
CREATE PROCEDURE sp_bitacora_registrar(
  IN p_id_usuario    INT,
  IN p_usuario_texto VARCHAR(500),
  IN p_evento        VARCHAR(100),
  IN p_recurso       VARCHAR(2000),
  IN p_ip            VARCHAR(200),
  IN p_detalle       VARCHAR(4000)
)
BEGIN
  INSERT INTO bitacora_acceso (fecha, id_usuario, usuario_texto, evento,
                               recurso, ip, detalle)
  VALUES (NOW(), p_id_usuario, LEFT(p_usuario_texto, 50), LEFT(p_evento, 30),
          LEFT(p_recurso, 150), LEFT(p_ip, 45), LEFT(p_detalle, 255));
END $$

-- -----------------------------------------------------------------------------
-- sp_bitacora_listar: últimos eventos (más reciente primero), filtro opcional
-- por evento. p_limite NULL o <= 0 -> 200; máximo 1000 para no saturar.
-- Usa ix_bitacora_evento_fecha (con filtro) o ix_bitacora_fecha (sin filtro).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_bitacora_listar $$
CREATE PROCEDURE sp_bitacora_listar(
  IN p_evento VARCHAR(30),
  IN p_limite INT
)
BEGIN
  DECLARE v_limite INT;
  SET v_limite = CASE WHEN p_limite IS NULL OR p_limite <= 0 THEN 200
                      WHEN p_limite > 1000 THEN 1000
                      ELSE p_limite END;

  SELECT id_bitacora, fecha, id_usuario, usuario_texto, evento, recurso,
         ip, detalle
    FROM bitacora_acceso
   WHERE p_evento IS NULL OR TRIM(p_evento) = '' OR evento = p_evento
   ORDER BY fecha DESC, id_bitacora DESC
   LIMIT v_limite;
END $$

-- -----------------------------------------------------------------------------
-- sp_tablero_kpis: alimenta el tablero en UNA sola llamada (4 resultsets).
--  (1) indicadores generales (1 fila)
--  (2) serie de los últimos 14 días; un CTE RECURSIVO genera los 14 días
--      para que los días sin eventos aparezcan en 0 (si no, la gráfica
--      saltaría días). Los conteos se filtran por rango de fecha para usar
--      el índice ix_bitacora_fecha.
--  (3) uso por menú: cuántos usuarios tiene asignado cada menú activo
--  (4) matriz usuario x menú: las filas de la tabla puente
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tablero_kpis $$
CREATE PROCEDURE sp_tablero_kpis()
BEGIN
  -- (1) KPIs
  SELECT
    (SELECT COUNT(*) FROM usuario)                       AS usuarios_total,
    (SELECT COUNT(*) FROM usuario WHERE estado = 1)      AS usuarios_activos,
    (SELECT COUNT(*) FROM menu WHERE estado = 1)         AS menus_activos,
    (SELECT COUNT(*) FROM usuario_menu)                  AS asignaciones_total,
    (SELECT COUNT(*) FROM bitacora_acceso
      WHERE evento = 'LOGIN_OK' AND fecha >= CURDATE())  AS logins_hoy,
    (SELECT COUNT(*) FROM bitacora_acceso
      WHERE evento = 'ACCESO_DENEGADO'
        AND fecha >= NOW() - INTERVAL 7 DAY)             AS denegados_7d,
    (SELECT COUNT(*) FROM bitacora_acceso
      WHERE evento = 'LOGIN_FALLIDO'
        AND fecha >= NOW() - INTERVAL 7 DAY)             AS fallidos_7d,
    (SELECT COUNT(*) FROM usuario
      WHERE bloqueado_hasta > NOW())                     AS bloqueados_ahora;

  -- (2) Serie diaria de 14 días (hoy incluido), días vacíos en 0.
  WITH RECURSIVE dias (dia) AS (
    SELECT CURDATE() - INTERVAL 13 DAY
    UNION ALL
    SELECT dia + INTERVAL 1 DAY FROM dias WHERE dia < CURDATE()
  ),
  eventos AS (
    SELECT DATE(fecha) AS dia,
           SUM(evento = 'LOGIN_OK')        AS logins_ok,
           SUM(evento = 'LOGIN_FALLIDO')   AS logins_fallidos,
           SUM(evento = 'ACCESO_DENEGADO') AS accesos_denegados
      FROM bitacora_acceso
     WHERE fecha >= CURDATE() - INTERVAL 13 DAY
       AND fecha <  CURDATE() + INTERVAL 1 DAY
     GROUP BY DATE(fecha)
  )
  SELECT d.dia,
         CAST(COALESCE(e.logins_ok, 0)         AS SIGNED) AS logins_ok,
         CAST(COALESCE(e.logins_fallidos, 0)   AS SIGNED) AS logins_fallidos,
         CAST(COALESCE(e.accesos_denegados, 0) AS SIGNED) AS accesos_denegados
    FROM dias d
    LEFT JOIN eventos e ON e.dia = d.dia
   ORDER BY d.dia;

  -- (3) Uso por menú.
  SELECT m.codigo, m.nombre, COUNT(um.id_usuario) AS total_usuarios
    FROM menu m
    LEFT JOIN usuario_menu um ON um.id_menu = m.id_menu
   WHERE m.estado = 1
   GROUP BY m.id_menu, m.codigo, m.nombre, m.orden
   ORDER BY m.orden;

  -- (4) Matriz de asignaciones.
  SELECT u.id_usuario, u.usuario, m.codigo
    FROM usuario_menu um
    JOIN usuario u ON u.id_usuario = um.id_usuario
    JOIN menu m    ON m.id_menu = um.id_menu
   ORDER BY u.usuario, m.orden;
END $$

-- -----------------------------------------------------------------------------
-- sp_cliente_listar: clientes con número de pólizas vigentes (no vencidas a
-- la fecha de hoy; incluye las que están por renovar).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cliente_listar $$
CREATE PROCEDURE sp_cliente_listar()
BEGIN
  SELECT c.id_cliente, c.nit, c.razon_social, c.sector, c.ciudad, c.fecha_alta,
         (SELECT COUNT(*) FROM poliza p
           WHERE p.id_cliente = c.id_cliente
             AND p.vigencia_hasta >= CURDATE()) AS polizas_vigentes
    FROM cliente c
   ORDER BY c.razon_social;
END $$

-- -----------------------------------------------------------------------------
-- sp_poliza_listar: pólizas con días para vencer. El estado se RECALCULA
-- contra la fecha actual (vencida si ya pasó, por renovar si faltan 30 días
-- o menos) para que nunca dependa de un proceso nocturno que lo actualice.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_poliza_listar $$
CREATE PROCEDURE sp_poliza_listar()
BEGIN
  SELECT p.id_poliza, p.numero, c.razon_social AS cliente, p.ramo,
         p.aseguradora, p.prima, p.vigencia_desde, p.vigencia_hasta,
         CASE WHEN p.vigencia_hasta < CURDATE() THEN 'VENCIDA'
              WHEN p.vigencia_hasta <= CURDATE() + INTERVAL 30 DAY THEN 'POR_RENOVAR'
              ELSE 'VIGENTE' END AS estado,
         DATEDIFF(p.vigencia_hasta, CURDATE()) AS dias_para_vencer
    FROM poliza p
    JOIN cliente c ON c.id_cliente = p.id_cliente
   ORDER BY p.vigencia_hasta;
END $$

-- -----------------------------------------------------------------------------
-- sp_siniestro_listar: siniestros con número de póliza y cliente.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_siniestro_listar $$
CREATE PROCEDURE sp_siniestro_listar()
BEGIN
  SELECT s.id_siniestro, s.numero, p.numero AS poliza, c.razon_social AS cliente,
         s.fecha_aviso, s.descripcion, s.valor_reclamado, s.estado
    FROM siniestro s
    JOIN poliza p  ON p.id_poliza = s.id_poliza
    JOIN cliente c ON c.id_cliente = p.id_cliente
   ORDER BY s.fecha_aviso DESC;
END $$

DELIMITER ;

-- =============================================================================
-- Atalaya - 03_datos_iniciales.sql : datos semilla.
-- Re-ejecutable: vacía las tablas y vuelve a cargar el estado inicial.
-- TODO lo de aquí es FICTICIO (empresas, NITs, aseguradoras, personas).
-- Las fechas son relativas a CURDATE()/NOW() para que siempre haya pólizas
-- por vencer y el tablero muestre actividad reciente sin importar el día en
-- que se instale.
-- =============================================================================

USE atalaya_acceso;

-- Vaciar en bloque. Se apagan las llaves foráneas solo durante el TRUNCATE
-- (TRUNCATE además reinicia los AUTO_INCREMENT, así los ids quedan 1..n).
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE siniestro;
TRUNCATE TABLE poliza;
TRUNCATE TABLE cliente;
TRUNCATE TABLE bitacora_acceso;
TRUNCATE TABLE usuario_menu;
TRUNCATE TABLE menu;
TRUNCATE TABLE usuario;
SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------------
-- Menús (7). El código funcional es el que usa [RequiereMenu("...")].
-- -----------------------------------------------------------------------------
INSERT INTO menu (id_menu, codigo, nombre, descripcion, ruta, icono, grupo, orden, estado) VALUES
  (1, 'TABLERO',    'Tablero',             'Indicadores de accesos, intentos fallidos y uso de menús.',     '#/tablero',    'speedometer2',        'Control',   1, 1),
  (2, 'USUARIOS',   'Usuarios',            'Creación, consulta y activación/inactivación de usuarios.',     '#/usuarios',   'people',              'Gestión',   2, 1),
  (3, 'ASIGNACION', 'Asignación de menús', 'Asignar y retirar menús a cada usuario.',                        '#/asignacion', 'diagram-3',           'Gestión',   3, 1),
  (4, 'AUDITORIA',  'Bitácora de accesos', 'Consulta de la bitácora de seguridad (logins, denegaciones).',  '#/auditoria',  'shield-check',        'Control',   4, 1),
  (5, 'CLIENTES',   'Clientes',            'Consulta de clientes tomadores de pólizas.',                     '#/clientes',   'building',            'Operación', 5, 1),
  (6, 'POLIZAS',    'Pólizas',             'Consulta de pólizas, vigencias y próximas renovaciones.',        '#/polizas',    'file-earmark-text',   'Operación', 6, 1),
  (7, 'SINIESTROS', 'Siniestros',          'Consulta de siniestros reclamados y su estado.',                 '#/siniestros', 'exclamation-diamond', 'Operación', 7, 1);

-- -----------------------------------------------------------------------------
-- Usuarios demo (credenciales de PRUEBA, documentadas en el contrato):
--   admin / Admin#2026        analista / Analista#2026
--   consulta / Consulta#2026  auditor / Auditor#2026 (INACTIVO)
-- hash_clave y sal_clave: PBKDF2-SHA256, 100000 iteraciones, sal aleatoria de
-- 16 bytes, hash de 32 bytes, ambos en Base64. Generados con Node
-- crypto.pbkdf2Sync(Buffer.from(clave,'utf8'), sal, 100000, 32, 'sha256');
-- verifican igual con .NET Rfc2898DeriveBytes(clave, sal, 100000, SHA256).
-- -----------------------------------------------------------------------------
INSERT INTO usuario (id_usuario, nombre, usuario, correo, hash_clave, sal_clave, iteraciones, estado, ultimo_acceso, fecha_creacion, creado_por) VALUES
  (1, 'Administrador Atalaya',  'admin',    'admin@atalaya.test',
      'TvQAorvyJvIbyQvMBz0TN2ki4VCp7Wrg9zZWF1wYguc=', 'cAI60Oz9AJkUX4MD0VLF6w==', 100000, 1,
      NULL, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:30:00'), NULL),
  (2, 'Laura Méndez Ríos',      'analista', 'analista@atalaya.test',
      'PWC2Ukkpd8tzKqD5cCUonue8FoiEtAnE9KSChuEocOk=', 'x+1ysGs4MYJtNwm+tOBNzg==', 100000, 1,
      NULL, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:05:00'), 1),
  (3, 'Andrés Quintero Patiño', 'consulta', 'consulta@atalaya.test',
      '/c21fzEonLcB1G5LX+1hPxQsPZ91kDCgmgNL0e4x3fE=', 'MU9qpH4ELUI2I7VYzWmmFA==', 100000, 1,
      NULL, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:07:00'), 1),
  (4, 'Camila Ospina Duarte',   'auditor',  'auditor@atalaya.test',
      'LJOrX3/KzRgqvrHuzh/diUKCeU4TbxmgjZ803ghHJzU=', 'XBV0BZ2U84ByNRRVvjnaqQ==', 100000, 0,
      NULL, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:09:00'), 1);

-- -----------------------------------------------------------------------------
-- Asignaciones (tabla puente). admin se auto-asignó al instalar; el resto las
-- hizo admin (id 1).
--   admin: los 7 | analista: TABLERO, POLIZAS, SINIESTROS
--   consulta: CLIENTES, POLIZAS | auditor: AUDITORIA
-- -----------------------------------------------------------------------------
INSERT INTO usuario_menu (id_usuario, id_menu, fecha_asignacion, asignado_por) VALUES
  (1, 1, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:31:00'), NULL),
  (1, 2, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:31:00'), NULL),
  (1, 3, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:31:00'), NULL),
  (1, 4, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:31:00'), NULL),
  (1, 5, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:31:00'), NULL),
  (1, 6, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:31:00'), NULL),
  (1, 7, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '07:31:00'), NULL),
  (2, 1, TIMESTAMP(CURDATE() - INTERVAL 2 DAY,  '11:03:00'), 1),
  (2, 6, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:15:00'), 1),
  (2, 7, TIMESTAMP(CURDATE() - INTERVAL 9 DAY,  '10:30:00'), 1),
  (3, 5, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:16:00'), 1),
  (3, 6, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:16:00'), 1),
  (4, 4, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:17:00'), 1);

-- -----------------------------------------------------------------------------
-- Clientes (10) - razones sociales y NITs inventados.
-- -----------------------------------------------------------------------------
INSERT INTO cliente (id_cliente, nit, razon_social, sector, ciudad, fecha_alta) VALUES
  ( 1, '900481237-4', 'Transportes Río Cauca S.A.S.',          'Transporte de carga', 'Cali',          CURDATE() - INTERVAL 1460 DAY),
  ( 2, '901122859-1', 'Alimentos La Sabana Dorada S.A.',       'Alimentos',           'Bogotá',        CURDATE() - INTERVAL 1210 DAY),
  ( 3, '830547126-8', 'Constructora Altos del Cerro S.A.S.',   'Construcción',        'Medellín',      CURDATE() - INTERVAL 980 DAY),
  ( 4, '900736410-2', 'Clínica Nueva Esperanza IPS',           'Salud',               'Bucaramanga',   CURDATE() - INTERVAL 860 DAY),
  ( 5, '901305772-6', 'Logística Puerto Caribe S.A.S.',        'Logística',           'Barranquilla',  CURDATE() - INTERVAL 720 DAY),
  ( 6, '860912354-0', 'Textiles Hilos de Oriente Ltda.',       'Manufactura',         'Pereira',       CURDATE() - INTERVAL 655 DAY),
  ( 7, '900258963-5', 'Agroindustrias Valle Verde S.A.',       'Agroindustria',       'Palmira',       CURDATE() - INTERVAL 540 DAY),
  ( 8, '901478520-3', 'Energía Solar del Llano S.A.S. E.S.P.', 'Energía',             'Villavicencio', CURDATE() - INTERVAL 410 DAY),
  ( 9, '900369147-9', 'Colegio Bilingüe Montes Claros',        'Educación',           'Manizales',     CURDATE() - INTERVAL 300 DAY),
  (10, '901654987-7', 'Tecnologías Cúmulo S.A.S.',             'Tecnología',          'Cartagena',     CURDATE() - INTERVAL 120 DAY);

-- -----------------------------------------------------------------------------
-- Pólizas (15). vigencia_hasta relativa a hoy: algunas vencidas, varias por
-- renovar (<= 30 días) y el resto vigentes. Aseguradoras inventadas.
-- -----------------------------------------------------------------------------
INSERT INTO poliza (id_poliza, numero, id_cliente, ramo, aseguradora, prima, vigencia_desde, vigencia_hasta) VALUES
  ( 1, 'ATL-TRM-2025-00118',  1, 'Transporte de mercancías',                'Cóndor Seguros S.A.',         48500000, CURDATE() - INTERVAL 357 DAY, CURDATE() + INTERVAL 8 DAY),
  ( 2, 'ATL-AUT-2025-00342',  1, 'Automóviles flota',                       'Seguros Altamar S.A.',        96200000, CURDATE() - INTERVAL 200 DAY, CURDATE() + INTERVAL 165 DAY),
  ( 3, 'ATL-TRD-2025-00077',  2, 'Todo riesgo daño material',               'Aseguradora Cordillera',     132750000, CURDATE() - INTERVAL 340 DAY, CURDATE() + INTERVAL 25 DAY),
  ( 4, 'ATL-RCE-2025-00215',  2, 'Responsabilidad civil extracontractual',  'Cóndor Seguros S.A.',         21300000, CURDATE() - INTERVAL 120 DAY, CURDATE() + INTERVAL 245 DAY),
  ( 5, 'ATL-CUM-2025-00430',  3, 'Cumplimiento',                            'Seguros Guadua S.A.',         15800000, CURDATE() - INTERVAL 380 DAY, CURDATE() - INTERVAL 15 DAY),
  ( 6, 'ATL-TRC-2025-00051',  3, 'Todo riesgo construcción',                'Aseguradora Cordillera',      87400000, CURDATE() - INTERVAL 90 DAY,  CURDATE() + INTERVAL 275 DAY),
  ( 7, 'ATL-RCP-2025-00189',  4, 'Responsabilidad civil profesional médica','Seguros Altamar S.A.',        64900000, CURDATE() - INTERVAL 362 DAY, CURDATE() + INTERVAL 3 DAY),
  ( 8, 'ATL-VGR-2025-00264',  4, 'Vida grupo',                              'Previsión Andina Vida',       38600000, CURDATE() - INTERVAL 60 DAY,  CURDATE() + INTERVAL 305 DAY),
  ( 9, 'ATL-TRM-2025-00402',  5, 'Transporte de mercancías',                'Seguros Altamar S.A.',        55100000, CURDATE() - INTERVAL 335 DAY, CURDATE() + INTERVAL 30 DAY),
  (10, 'ATL-MGL-2025-00133',  6, 'Manejo global comercial',                 'Seguros Guadua S.A.',          9750000, CURDATE() - INTERVAL 400 DAY, CURDATE() - INTERVAL 35 DAY),
  (11, 'ATL-TRD-2025-00298',  6, 'Todo riesgo daño material',               'Cóndor Seguros S.A.',         71200000, CURDATE() - INTERVAL 150 DAY, CURDATE() + INTERVAL 215 DAY),
  (12, 'ATL-AGR-2025-00087',  7, 'Agrícola multirriesgo',                   'Aseguradora Cordillera',      44300000, CURDATE() - INTERVAL 352 DAY, CURDATE() + INTERVAL 13 DAY),
  (13, 'ATL-TRD-2025-00371',  8, 'Todo riesgo daño material',               'Previsión Andina Generales', 158900000, CURDATE() - INTERVAL 45 DAY,  CURDATE() + INTERVAL 320 DAY),
  (14, 'ATL-RCE-2025-00456',  9, 'Responsabilidad civil extracontractual',  'Seguros Guadua S.A.',         12400000, CURDATE() - INTERVAL 368 DAY, CURDATE() - INTERVAL 3 DAY),
  (15, 'ATL-CIB-2025-00019', 10, 'Riesgos cibernéticos',                    'Seguros Altamar S.A.',        29900000, CURDATE() - INTERVAL 30 DAY,  CURDATE() + INTERVAL 335 DAY);

-- El estado almacenado se calcula con la misma regla que usa sp_poliza_listar.
UPDATE poliza
   SET estado = CASE WHEN vigencia_hasta < CURDATE() THEN 'VENCIDA'
                     WHEN vigencia_hasta <= CURDATE() + INTERVAL 30 DAY THEN 'POR_RENOVAR'
                     ELSE 'VIGENTE' END
 WHERE id_poliza > 0;

-- -----------------------------------------------------------------------------
-- Siniestros (10).
-- -----------------------------------------------------------------------------
INSERT INTO siniestro (id_siniestro, numero, id_poliza, fecha_aviso, descripcion, valor_reclamado, estado) VALUES
  ( 1, 'SIN-2026-0101',  1, CURDATE() - INTERVAL 40 DAY,  'Volcamiento de tractomula en la vía Buga - Tuluá con pérdida parcial de carga.',  185000000, 'EN_AJUSTE'),
  ( 2, 'SIN-2026-0102',  2, CURDATE() - INTERVAL 12 DAY,  'Colisión de camioneta de la flota en zona urbana, daños a tercero.',                23500000, 'ABIERTO'),
  ( 3, 'SIN-2026-0103',  3, CURDATE() - INTERVAL 95 DAY,  'Inundación en bodega de materias primas por desbordamiento de canal.',            312400000, 'PAGADO'),
  ( 4, 'SIN-2026-0104',  6, CURDATE() - INTERVAL 21 DAY,  'Caída de grúa torre sobre estructura en obra, sin lesionados.',                    97800000, 'EN_AJUSTE'),
  ( 5, 'SIN-2026-0105',  7, CURDATE() - INTERVAL 160 DAY, 'Reclamación de paciente por presunta mala práctica en procedimiento ambulatorio.',  450000000, 'OBJETADO'),
  ( 6, 'SIN-2026-0106',  9, CURDATE() - INTERVAL 5 DAY,   'Hurto de contenedor en patio de tránsito del puerto.',                            128300000, 'ABIERTO'),
  ( 7, 'SIN-2026-0107', 11, CURDATE() - INTERVAL 70 DAY,  'Incendio en cuarto de calderas con daño a maquinaria de tejido.',                 205600000, 'PAGADO'),
  ( 8, 'SIN-2026-0108', 12, CURDATE() - INTERVAL 33 DAY,  'Pérdida de cultivo de caña por granizada.',                                         76400000, 'EN_AJUSTE'),
  ( 9, 'SIN-2026-0109', 13, CURDATE() - INTERVAL 2 DAY,   'Descarga eléctrica atmosférica que afectó inversores del parque solar.',            58900000, 'ABIERTO'),
  (10, 'SIN-2026-0110', 15, CURDATE() - INTERVAL 18 DAY,  'Secuestro de datos (ransomware) en servidores de producción.',                    142000000, 'EN_AJUSTE');

-- -----------------------------------------------------------------------------
-- Bitácora: ~2 semanas de actividad ficticia (logins, fallos, una ráfaga de
-- fuerza bruta con bloqueo, accesos denegados y cambios de administración)
-- para que el tablero se vea con datos desde el primer arranque.
-- -----------------------------------------------------------------------------
INSERT INTO bitacora_acceso (fecha, id_usuario, usuario_texto, evento, recurso, ip, detalle) VALUES
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '07:04:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '07:18:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/users', '192.168.10.22', 'No tiene autorización para el menú USUARIOS.'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:05:00'), 1, 'admin', 'USUARIO_CREADO', '/api/users', '10.20.4.15', 'Creó el usuario analista (id 2)'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:07:00'), 1, 'admin', 'USUARIO_CREADO', '/api/users', '10.20.4.15', 'Creó el usuario consulta (id 3)'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:09:00'), 1, 'admin', 'USUARIO_CREADO', '/api/users', '10.20.4.15', 'Creó el usuario auditor (id 4)'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:15:00'), 1, 'admin', 'MENUS_ACTUALIZADOS', '/api/users/2/menus', '10.20.4.15', 'analista: agregados 3, retirados 0'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:16:00'), 1, 'admin', 'MENUS_ACTUALIZADOS', '/api/users/3/menus', '10.20.4.15', 'consulta: agregados 2, retirados 0'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:17:00'), 1, 'admin', 'MENUS_ACTUALIZADOS', '/api/users/4/menus', '10.20.4.15', 'auditor: agregados 1, retirados 0'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:18:00'), 3, 'consulta', 'LOGIN_FALLIDO', '/api/auth/login', '192.168.10.22', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:20:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '08:51:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/auditoria', '192.168.10.22', 'No tiene autorización para el menú AUDITORIA.'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '12:16:00'), 3, 'consulta', 'LOGIN_FALLIDO', '/api/auth/login', '192.168.10.22', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '12:18:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '13:02:00'), 3, 'consulta', 'LOGIN_FALLIDO', '/api/auth/login', '192.168.10.22', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '13:04:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '16:49:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '17:59:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '22:39:00'), NULL, 'administrador', 'LOGIN_FALLIDO', '/api/auth/login', '190.85.12.201', 'Usuario inexistente'),
  (TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '09:15:00'), 1, 'admin', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.15', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '09:17:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '11:15:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '11:45:00'), 1, 'admin', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.15', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '11:47:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '13:11:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '10:14:00'), 1, 'admin', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.15', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '10:16:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '11:51:00'), 3, 'consulta', 'LOGIN_FALLIDO', '/api/auth/login', '192.168.10.22', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '11:53:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '12:07:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/auditoria', '192.168.10.22', 'No tiene autorización para el menú AUDITORIA.'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '14:53:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '15:29:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '15:46:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/auditoria', '192.168.10.22', 'No tiene autorización para el menú AUDITORIA.'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '16:46:00'), 2, 'analista', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.37', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '16:48:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '07:18:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '08:37:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '13:18:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '14:04:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '14:21:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/users', '192.168.10.22', 'No tiene autorización para el menú USUARIOS.'),
  (TIMESTAMP(CURDATE() - INTERVAL 9 DAY, '10:30:00'), 1, 'admin', 'MENUS_ACTUALIZADOS', '/api/users/2/menus', '10.20.4.15', 'analista: agregados 1, retirados 1'),
  (TIMESTAMP(CURDATE() - INTERVAL 9 DAY, '15:07:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '11:50:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '17:40:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '18:04:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/siniestros', '192.168.10.22', 'No tiene autorización para el menú SINIESTROS.'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '08:17:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '08:41:00'), 2, 'analista', 'ACCESO_DENEGADO', '/api/clientes', '10.20.4.37', 'No tiene autorización para el menú CLIENTES.'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '09:17:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '11:31:00'), 1, 'admin', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.15', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '11:33:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '16:02:00'), 1, 'admin', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.15', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '16:04:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '17:00:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '05:12:00'), NULL, 'administrador', 'LOGIN_FALLIDO', '/api/auth/login', '190.85.12.201', 'Usuario inexistente'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '07:29:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '09:11:00'), 3, 'consulta', 'LOGIN_FALLIDO', '/api/auth/login', '192.168.10.22', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '09:13:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '10:44:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '13:31:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:41:00'), 4, 'auditor', 'LOGIN_FALLIDO', '/api/auth/login', '181.52.33.10', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:42:00'), 4, 'auditor', 'LOGIN_FALLIDO', '/api/auth/login', '181.52.33.10', 'Clave incorrecta (intento 2 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:43:00'), 4, 'auditor', 'LOGIN_FALLIDO', '/api/auth/login', '181.52.33.10', 'Clave incorrecta (intento 3 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:44:00'), 4, 'auditor', 'LOGIN_FALLIDO', '/api/auth/login', '181.52.33.10', 'Clave incorrecta (intento 4 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:45:00'), 4, 'auditor', 'LOGIN_FALLIDO', '/api/auth/login', '181.52.33.10', 'Clave incorrecta (intento 5 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:46:00'), 4, 'auditor', 'LOGIN_BLOQUEADO', '/api/auth/login', '181.52.33.10', 'Usuario bloqueado 15 minutos por 5 intentos fallidos'),
  (TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:52:00'), 4, 'auditor', 'LOGIN_BLOQUEADO', '/api/auth/login', '181.52.33.10', 'Intento durante bloqueo (faltan 9 minutos)'),
  (TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '09:10:00'), 1, 'admin', 'USUARIO_ESTADO', '/api/users/4/estado', '10.20.4.15', 'Inactivó al usuario auditor (id 4)'),
  (TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '09:12:00'), 4, 'auditor', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.88', 'Usuario inactivo'),
  (TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '12:13:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '13:03:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '14:41:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '14:46:00'), 2, 'analista', 'ACCESO_DENEGADO', '/api/auditoria', '10.20.4.37', 'No tiene autorización para el menú AUDITORIA.'),
  (TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '17:32:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '07:39:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '07:45:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '08:10:00'), 2, 'analista', 'ACCESO_DENEGADO', '/api/auditoria', '10.20.4.37', 'No tiene autorización para el menú AUDITORIA.'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '08:11:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/siniestros', '192.168.10.22', 'No tiene autorización para el menú SINIESTROS.'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '09:42:00'), NULL, 'administrador', 'LOGIN_FALLIDO', '/api/auth/login', '190.85.12.201', 'Usuario inexistente'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '10:27:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '10:37:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/users', '192.168.10.22', 'No tiene autorización para el menú USUARIOS.'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '13:52:00'), 2, 'analista', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.37', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '13:54:00'), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '16:25:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '07:32:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Safari 18 / macOS'),
  (TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '07:45:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/tablero', '192.168.10.22', 'No tiene autorización para el menú TABLERO.'),
  (TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '07:58:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '08:04:00'), 3, 'consulta', 'ACCESO_DENEGADO', '/api/auditoria', '192.168.10.22', 'No tiene autorización para el menú AUDITORIA.'),
  (TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '16:34:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '18:16:00'), NULL, 'soporte', 'LOGIN_FALLIDO', '/api/auth/login', '190.85.12.201', 'Usuario inexistente'),
  (TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '11:03:00'), 1, 'admin', 'MENUS_ACTUALIZADOS', '/api/users/2/menus', '10.20.4.15', 'analista: agregados 1, retirados 1'),
  (TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '15:07:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Edge 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '15:32:00'), 1, 'admin', 'LOGIN_FALLIDO', '/api/auth/login', '10.20.4.15', 'Clave incorrecta (intento 1 de 5)'),
  (TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '15:34:00'), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '16:12:00'), 3, 'consulta', 'LOGIN_OK', '/api/auth/login', '192.168.10.22', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (GREATEST(TIMESTAMP(CURDATE()), NOW() - INTERVAL 35 MINUTE), 2, 'analista', 'LOGIN_OK', '/api/auth/login', '10.20.4.37', 'Inicio de sesión exitoso - Firefox 131 / Windows 10'),
  (GREATEST(TIMESTAMP(CURDATE()), NOW() - INTERVAL 28 MINUTE), 2, 'analista', 'ACCESO_DENEGADO', '/api/menus', '10.20.4.37', 'No tiene autorización para el menú ASIGNACION.'),
  (GREATEST(TIMESTAMP(CURDATE()), NOW() - INTERVAL 21 MINUTE), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (GREATEST(TIMESTAMP(CURDATE()), NOW() - INTERVAL 14 MINUTE), 1, 'admin', 'LOGIN_OK', '/api/auth/login', '10.20.4.15', 'Inicio de sesión exitoso - Chrome 129 / Windows 11'),
  (GREATEST(TIMESTAMP(CURDATE()), NOW() - INTERVAL 7 MINUTE), NULL, 'jgomez', 'LOGIN_FALLIDO', '/api/auth/login', '186.29.144.7', 'Usuario inexistente');

-- Último acceso de cada usuario coherente con su último LOGIN_OK en bitácora.
UPDATE usuario u
   SET u.ultimo_acceso = (SELECT MAX(b.fecha) FROM bitacora_acceso b
                           WHERE b.id_usuario = u.id_usuario AND b.evento = 'LOGIN_OK')
 WHERE u.id_usuario > 0;
