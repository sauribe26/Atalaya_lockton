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
