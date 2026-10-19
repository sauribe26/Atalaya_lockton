/* =====================================================================
   api.js — Cliente HTTP central de Atalaya.
   · Agrega el encabezado Authorization: Bearer <token> en cada llamada.
   · Interpreta el formato de error uniforme del API
     { estado, codigo, mensaje, detalles, traza } y lanza ErrorApi.
   · Un 401 en cualquier llamada autenticada limpia la sesión y vuelve
     al login (el token venció o fue rechazado por el servidor).
   Todas las rutas son relativas: el front y el API viven en el mismo sitio.
   ===================================================================== */
import { obtenerToken, cerrarSesion } from './sesion.js';

/** Error de negocio o de red devuelto por el API, ya interpretado. */
export class ErrorApi extends Error {
  /**
   * @param {number} estado código HTTP (0 = sin conexión)
   * @param {string} codigo código funcional, ej. ACCESO_DENEGADO
   * @param {string} mensaje texto para el usuario
   * @param {Object<string,string>|null} detalles errores por campo (400)
   * @param {any} cuerpo cuerpo JSON completo de la respuesta
   */
  constructor(estado, codigo, mensaje, detalles = null, cuerpo = null) {
    super(mensaje);
    this.name = 'ErrorApi';
    this.estado = estado;
    this.codigo = codigo;
    this.mensaje = mensaje;
    this.detalles = detalles;
    this.cuerpo = cuerpo;
  }
}

/** Mensajes por defecto cuando el servidor no envía el formato uniforme. */
const MENSAJES_HTTP = {
  0: 'No fue posible conectar con el servidor. Revise su conexión.',
  400: 'La solicitud tiene datos no válidos.',
  401: 'Su sesión no es válida o expiró.',
  403: 'No tiene autorización para esta acción.',
  404: 'El recurso solicitado no existe.',
  409: 'La operación entra en conflicto con los datos actuales.',
  423: 'El usuario está bloqueado temporalmente.',
  500: 'Ocurrió un error inesperado en el servidor.'
};

/** Intenta leer el cuerpo como JSON; si no se puede, devuelve null. */
async function leerJson(respuesta) {
  const texto = await respuesta.text();
  if (!texto) return null;
  try { return JSON.parse(texto); } catch { return { mensaje: texto.slice(0, 300) }; }
}

/**
 * Ejecuta una petición al API.
 * @param {string} metodo GET | POST | PUT | PATCH | DELETE
 * @param {string} ruta ruta relativa, ej. '/api/users'
 * @param {any} [cuerpo] objeto a enviar como JSON
 * @param {{anonimo?:boolean, sin401?:boolean}} [opciones]
 *   anonimo: no envía token (login). sin401: no redirige en 401.
 * @returns {Promise<any>} JSON de la respuesta (null si viene vacía)
 * @throws {ErrorApi}
 */
export async function solicitar(metodo, ruta, cuerpo, opciones = {}) {
  const encabezados = { 'Accept': 'application/json' };
  if (cuerpo !== undefined) encabezados['Content-Type'] = 'application/json';
  const token = obtenerToken();
  if (token && !opciones.anonimo) encabezados['Authorization'] = `Bearer ${token}`;

  let respuesta;
  try {
    respuesta = await fetch(ruta, {
      method: metodo,
      headers: encabezados,
      body: cuerpo !== undefined ? JSON.stringify(cuerpo) : undefined,
      cache: 'no-store'
    });
  } catch {
    throw new ErrorApi(0, 'SIN_CONEXION', MENSAJES_HTTP[0]);
  }

  const datos = await leerJson(respuesta);
  if (respuesta.ok) return datos;

  const estado = respuesta.status;
  if (estado === 401 && !opciones.anonimo && !opciones.sin401) {
    cerrarSesion('expirada');
  }
  const d = datos || {};
  throw new ErrorApi(
    estado,
    d.codigo || `HTTP_${estado}`,
    d.mensaje || d.Message || MENSAJES_HTTP[estado] || `Error ${estado}`,
    d.detalles || null,
    datos
  );
}

/**
 * Hace una petición "de prueba" que nunca lanza: devuelve el estado y el
 * cuerpo tal cual. Se usa en la vista "Sin acceso" para mostrar el 403 real.
 * @param {string} ruta
 * @returns {Promise<{estado:number, cuerpo:any}>}
 */
export async function sondear(ruta) {
  const token = obtenerToken();
  try {
    const r = await fetch(ruta, {
      headers: { 'Accept': 'application/json', ...(token ? { 'Authorization': `Bearer ${token}` } : {}) },
      cache: 'no-store'
    });
    const cuerpo = await leerJson(r);
    if (r.status === 401) cerrarSesion('expirada');
    return { estado: r.status, cuerpo };
  } catch {
    return { estado: 0, cuerpo: { mensaje: MENSAJES_HTTP[0] } };
  }
}

/** Atajos por verbo HTTP. */
export const api = {
  get: (ruta, op) => solicitar('GET', ruta, undefined, op),
  post: (ruta, cuerpo, op) => solicitar('POST', ruta, cuerpo, op),
  put: (ruta, cuerpo, op) => solicitar('PUT', ruta, cuerpo, op),
  patch: (ruta, cuerpo, op) => solicitar('PATCH', ruta, cuerpo, op)
};
