/* =====================================================================
   enrutador.js — Enrutador por hash (#/ruta?param=valor) con guardia.
   · Rutas públicas para cualquier usuario autenticado: inicio, manual,
     sin-acceso.
   · Rutas de módulo: solo si el menú está entre los asignados al usuario
     (los que devolvió /api/auth/yo). Si no, se muestra la vista
     "Sin acceso", que además consulta el endpoint real del módulo para
     enseñar el 403 del servidor (la seguridad vive en el backend; el
     front solo oculta opciones).
   · Cada vista es un módulo ES en ./vistas/ que exporta
     mostrar(contenedor, ctx) y puede devolver una función de limpieza.
   ===================================================================== */

/**
 * Catálogo de módulos conocidos por el front: ruta → código de menú,
 * endpoint del API que lo protege y datos de presentación de respaldo.
 */
export const MODULOS = {
  tablero:    { codigo: 'TABLERO',    endpoint: '/api/tablero',    vista: 'tablero',    nombre: 'Tablero',              icono: 'speedometer2',        grupo: 'Control' },
  usuarios:   { codigo: 'USUARIOS',   endpoint: '/api/users',      vista: 'usuarios',   nombre: 'Usuarios',             icono: 'people',              grupo: 'Gestión' },
  asignacion: { codigo: 'ASIGNACION', endpoint: '/api/menus',      vista: 'asignacion', nombre: 'Asignación de menús',  icono: 'diagram-3',           grupo: 'Gestión' },
  auditoria:  { codigo: 'AUDITORIA',  endpoint: '/api/auditoria',  vista: 'auditoria',  nombre: 'Bitácora de accesos',  icono: 'shield-check',        grupo: 'Control' },
  clientes:   { codigo: 'CLIENTES',   endpoint: '/api/clientes',   vista: 'clientes',   nombre: 'Clientes',             icono: 'building',            grupo: 'Operación' },
  polizas:    { codigo: 'POLIZAS',    endpoint: '/api/polizas',    vista: 'polizas',    nombre: 'Pólizas',              icono: 'file-earmark-text',   grupo: 'Operación' },
  siniestros: { codigo: 'SINIESTROS', endpoint: '/api/siniestros', vista: 'siniestros', nombre: 'Siniestros',           icono: 'exclamation-diamond', grupo: 'Operación' }
};

/** Rutas que no dependen de menús asignados. */
export const PUBLICAS = {
  'inicio':     { vista: 'inicio',    nombre: 'Inicio',          icono: 'house-door' },
  'manual':     { vista: 'manual',    nombre: 'Manual de uso',   icono: 'journal-text' },
  'sin-acceso': { vista: 'sinacceso', nombre: 'Sin acceso',      icono: 'shield-x' }
};

/**
 * Convierte la ruta de un menú ("#/usuarios") en su clave ("usuarios").
 * @param {string} ruta
 */
export function claveDeRuta(ruta) {
  return String(ruta || '').replace(/^#?\/?/, '').split('?')[0].trim().toLowerCase();
}

/**
 * Lee el hash actual.
 * @returns {{ruta:string, params:URLSearchParams}}
 */
export function analizarHash() {
  const h = window.location.hash.replace(/^#\/?/, '');
  const [ruta, consulta] = h.split('?');
  return { ruta: (ruta || 'inicio').toLowerCase(), params: new URLSearchParams(consulta || '') };
}

/**
 * Crea el enrutador.
 * @param {{
 *   contenedor: HTMLElement,
 *   contexto: () => {usuario:any, menus:any[], refrescarMenus:Function},
 *   alNavegar: (info:{ruta:string, nombre:string, icono:string, grupo:string|null, permitido:boolean}) => void
 * }} opciones
 * @returns {{iniciar:Function, recargar:Function, ir:Function}}
 */
export function crearEnrutador({ contenedor, contexto, alNavegar }) {
  let limpieza = null;
  let turno = 0;

  async function resolver() {
    const { ruta, params } = analizarHash();
    const ctx = contexto();
    const permitidas = new Map((ctx.menus || []).map((m) => [claveDeRuta(m.ruta), m]));

    let vista, info;
    if (PUBLICAS[ruta]) {
      const p = PUBLICAS[ruta];
      vista = p.vista;
      info = { ruta, nombre: p.nombre, icono: p.icono, grupo: null, permitido: true };
    } else if (MODULOS[ruta]) {
      const mod = MODULOS[ruta];
      const menu = permitidas.get(ruta);
      if (menu) {
        vista = mod.vista;
        info = { ruta, nombre: menu.nombre, icono: menu.icono || mod.icono, grupo: menu.grupo || mod.grupo, permitido: true };
      } else {
        // Guardia: el usuario no tiene el menú → "Sin acceso" con la prueba del servidor.
        vista = 'sinacceso';
        info = { ruta, nombre: mod.nombre, icono: 'shield-x', grupo: mod.grupo, permitido: false };
      }
    } else {
      window.location.replace('#/inicio');
      return;
    }

    const miTurno = ++turno;
    if (typeof limpieza === 'function') { try { limpieza(); } catch { /* sin efecto */ } }
    limpieza = null;
    alNavegar(info);

    try {
      const modulo = await import(`./vistas/${vista}.js`);
      if (miTurno !== turno) return; // el usuario ya navegó a otra parte
      contenedor.innerHTML = '';
      const destino = document.createElement('div');
      destino.className = 'vista';
      contenedor.appendChild(destino);
      const r = await modulo.mostrar(destino, {
        ...ctx,
        params,
        ruta,
        modulo: MODULOS[ruta] ? { ...MODULOS[ruta], ruta } : null,
        vigente: () => miTurno === turno
      });
      if (miTurno === turno) limpieza = r || null;
      else if (typeof r === 'function') r();
    } catch (err) {
      if (miTurno !== turno) return;
      console.error(err);
      contenedor.innerHTML = '<div class="aviso error"><i class="bi bi-bug" aria-hidden="true"></i><div>No fue posible cargar esta vista. Recargue la página.</div></div>';
    }
  }

  return {
    /** Empieza a escuchar cambios del hash y pinta la ruta actual. */
    iniciar() {
      window.addEventListener('hashchange', resolver);
      if (!window.location.hash) window.location.replace('#/inicio');
      resolver();
    },
    /** Vuelve a pintar la ruta actual (p. ej. tras cambiar los menús). */
    recargar: resolver,
    /** Navega a una ruta: ir('usuarios') o ir('asignacion?usuario=3'). */
    ir(ruta) { window.location.hash = `#/${ruta}`; }
  };
}
