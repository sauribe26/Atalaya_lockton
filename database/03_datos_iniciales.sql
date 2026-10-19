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
