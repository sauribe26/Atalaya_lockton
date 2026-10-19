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
