/* =====================================================================
   sesion.js — Manejo de la sesión del usuario en el navegador.
   Guarda el token JWT y los datos básicos del usuario en sessionStorage
   (se borran al cerrar la pestaña). No decide permisos: eso lo hace el
   servidor en cada petición; aquí solo se recuerda "quién soy".
   ===================================================================== */

const CLAVE_TOKEN = 'atalaya.token';
const CLAVE_USUARIO = 'atalaya.usuario';
const CLAVE_EXPIRA = 'atalaya.expira';

/** Lee un valor de sessionStorage sin romper si el almacenamiento está bloqueado. */
function leer(clave) {
  try { return sessionStorage.getItem(clave); } catch { return null; }
}

/** Escribe (o borra con null) un valor de sessionStorage de forma segura. */
function escribir(clave, valor) {
  try {
    if (valor === null || valor === undefined) sessionStorage.removeItem(clave);
    else sessionStorage.setItem(clave, valor);
  } catch { /* almacenamiento no disponible: la sesión vivirá solo en memoria */ }
}

/**
 * Guarda la sesión tras un login exitoso.
 * @param {string} token JWT devuelto por /api/auth/login
 * @param {{id:number,nombre:string,usuario:string,correo:string}} usuario
 * @param {string} [expiraEn] fecha ISO de expiración del token
 */
export function guardarSesion(token, usuario, expiraEn) {
  escribir(CLAVE_TOKEN, token);
  escribir(CLAVE_USUARIO, JSON.stringify(usuario || {}));
  escribir(CLAVE_EXPIRA, expiraEn || null);
}

/** @returns {string|null} token JWT vigente o null si no hay / ya expiró. */
export function obtenerToken() {
  const token = leer(CLAVE_TOKEN);
  if (!token) return null;
  const expira = leer(CLAVE_EXPIRA);
  if (expira) {
    const t = Date.parse(expira);
    if (!Number.isNaN(t) && t <= Date.now()) { limpiarSesion(); return null; }
  }
  return token;
}

/** @returns {{id:number,nombre:string,usuario:string,correo:string}|null} usuario guardado. */
export function obtenerUsuario() {
  const crudo = leer(CLAVE_USUARIO);
  if (!crudo) return null;
  try { return JSON.parse(crudo); } catch { return null; }
}

/** Actualiza los datos del usuario guardado (p. ej. tras /api/auth/yo). */
export function actualizarUsuario(usuario) {
  escribir(CLAVE_USUARIO, JSON.stringify(usuario || {}));
}

/** @returns {boolean} true si hay un token guardado y no vencido. */
export function haySesion() {
  return !!obtenerToken();
}

/** Borra todos los datos de sesión del navegador. */
export function limpiarSesion() {
  escribir(CLAVE_TOKEN, null);
  escribir(CLAVE_USUARIO, null);
  escribir(CLAVE_EXPIRA, null);
}

/**
 * Cierra la sesión y vuelve a la pantalla de ingreso.
 * @param {string} [motivo] 'expirada' | 'salir' — se muestra un aviso en el login.
 */
export function cerrarSesion(motivo) {
  limpiarSesion();
  const sufijo = motivo ? `?motivo=${encodeURIComponent(motivo)}` : '';
  window.location.replace(`login.html${sufijo}`);
}
