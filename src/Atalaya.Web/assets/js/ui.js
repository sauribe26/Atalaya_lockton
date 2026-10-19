/* =====================================================================
   ui.js — Utilidades de interfaz compartidas por todas las vistas.
   · esc(): escape HTML. REGLA: todo dato que venga del API y se pinte
     con innerHTML pasa por esc() (o se asigna con textContent) → evita XSS.
   · Formatos propios (pesos con punto de miles, fechas) que NO dependen
     de la configuración regional del equipo.
   · Toasts de Bootstrap, overlay "Procesando…", esqueletos, estados vacíos,
     animación de conteo y resaltado de JSON.
   ===================================================================== */

/**
 * Escapa un valor para insertarlo de forma segura en HTML.
 * @param {any} valor
 * @returns {string}
 */
export function esc(valor) {
  if (valor === null || valor === undefined) return '';
  return String(valor)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Entero con punto de miles fijo: 1234567 → "1.234.567". No usa toLocaleString.
 * @param {number|string} n
 * @returns {string}
 */
export function miles(n) {
  const num = Math.round(Number(n) || 0);
  const signo = num < 0 ? '-' : '';
  const digitos = String(Math.abs(num));
  let salida = '';
  for (let i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 === 0) salida += '.';
    salida += digitos[i];
  }
  return signo + salida;
}

/**
 * Valor en pesos: 150000 → "$ 150.000".
 * @param {number|string} n
 * @returns {string}
 */
export function pesos(n) {
  return `$ ${miles(n)}`;
}

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/**
 * Descompone una fecha ISO ("2026-10-19" o "2026-10-19T08:05:00") sin
 * conversión de zona horaria (la hora se muestra tal como la envía el servidor).
 * @param {string} iso
 * @returns {{a:number,m:number,d:number,h:number,mi:number}|null}
 */
export function partesFecha(iso) {
  if (!iso) return null;
  const r = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?/.exec(String(iso));
  if (!r) return null;
  return { a: +r[1], m: +r[2], d: +r[3], h: r[4] ? +r[4] : 0, mi: r[5] ? +r[5] : 0 };
}

const dos = (n) => String(n).padStart(2, '0');

/** "2026-10-19" → "19 oct 2026". */
export function fecha(iso) {
  const p = partesFecha(iso);
  return p ? `${p.d} ${MESES[p.m - 1]} ${p.a}` : '—';
}

/** "2026-10-19T08:05:00" → "19 oct 2026 · 08:05". */
export function fechaHora(iso) {
  const p = partesFecha(iso);
  return p ? `${p.d} ${MESES[p.m - 1]} ${p.a} · ${dos(p.h)}:${dos(p.mi)}` : '—';
}

/** "2026-10-19" → "19 oct" (para ejes de gráficos). */
export function fechaCorta(iso) {
  const p = partesFecha(iso);
  return p ? `${p.d} ${MESES[p.m - 1]}` : '';
}

/**
 * Iniciales de un nombre: "Ana María Pérez" → "AP".
 * @param {string} nombre
 */
export function iniciales(nombre) {
  const partes = String(nombre || '?').trim().split(/\s+/).filter(Boolean);
  if (!partes.length) return '?';
  const primera = partes[0][0];
  const ultima = partes.length > 1 ? partes[partes.length - 1][0] : (partes[0][1] || '');
  return (primera + ultima).toUpperCase();
}

/**
 * Retrasa la ejecución de una función hasta que dejen de llamarla (búsquedas).
 * @param {Function} fn
 * @param {number} [ms=300]
 */
export function debounce(fn, ms = 300) {
  let t;
  return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}

/** Normaliza texto para búsquedas: minúsculas y sin tildes. */
export function normalizar(texto) {
  return String(texto ?? '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
}

/* ---------- Toasts ---------- */
const ICONO_TOAST = { ok: 'check-circle-fill', error: 'x-octagon-fill', info: 'info-circle-fill' };

/**
 * Muestra una notificación breve (toast de Bootstrap).
 * @param {string} mensaje texto plano (se asigna con textContent)
 * @param {'ok'|'error'|'info'} [tipo='info']
 */
export function aviso(mensaje, tipo = 'info') {
  let zona = document.querySelector('.zona-toasts');
  if (!zona) {
    zona = document.createElement('div');
    zona.className = 'zona-toasts';
    zona.setAttribute('aria-live', 'polite');
    document.body.appendChild(zona);
  }
  const el = document.createElement('div');
  el.className = `toast ${tipo}`;
  el.setAttribute('role', tipo === 'error' ? 'alert' : 'status');
  el.innerHTML = `<div class="toast-body"><i class="bi bi-${ICONO_TOAST[tipo] || ICONO_TOAST.info}" aria-hidden="true"></i><span></span>
    <button type="button" class="btn-close ms-auto" data-bs-dismiss="toast" aria-label="Cerrar"></button></div>`;
  el.querySelector('span').textContent = mensaje;
  zona.appendChild(el);
  const t = window.bootstrap ? new window.bootstrap.Toast(el, { delay: tipo === 'error' ? 6000 : 3500 }) : null;
  el.addEventListener('hidden.bs.toast', () => el.remove());
  if (t) t.show(); else setTimeout(() => el.remove(), 4000);
}

/* ---------- Overlay de carga ---------- */
let contadorCarga = 0;

/**
 * Muestra u oculta el overlay "Procesando…" (admite llamadas anidadas).
 * @param {boolean} visible
 * @param {string} [texto='Procesando…']
 */
export function procesando(visible, texto = 'Procesando…') {
  let ov = document.querySelector('.overlay-carga');
  if (!ov) {
    ov = document.createElement('div');
    ov.className = 'overlay-carga';
    ov.setAttribute('role', 'status');
    ov.setAttribute('aria-live', 'polite');
    ov.innerHTML = '<div class="caja"><div class="spinner-border" aria-hidden="true"></div><span></span></div>';
    document.body.appendChild(ov);
  }
  contadorCarga = Math.max(0, contadorCarga + (visible ? 1 : -1));
  ov.querySelector('span').textContent = texto;
  ov.classList.toggle('visible', contadorCarga > 0);
}

/* ---------- Bloques reutilizables (HTML) ---------- */

/**
 * HTML de un estado vacío.
 * @param {string} icono nombre Bootstrap Icons (sin "bi-")
 * @param {string} titulo
 * @param {string} [texto]
 */
export function vacio(icono, titulo, texto = '') {
  return `<div class="vacio-bloque"><i class="bi bi-${esc(icono)}" aria-hidden="true"></i><b>${esc(titulo)}</b>${texto ? `<span>${esc(texto)}</span>` : ''}</div>`;
}

/** HTML de esqueleto de carga para una tabla/lista. */
export function esqueletoFilas(n = 6) {
  return `<div class="tarjeta" aria-busy="true" aria-label="Cargando">${'<div class="esqueleto esq-fila"></div>'.repeat(n)}</div>`;
}

/** HTML de esqueleto para una rejilla de bloques (KPIs, tarjetas). */
export function esqueletoBloques(n = 4, clase = 'kpis') {
  return `<div class="${clase}" aria-busy="true">${'<div class="esqueleto esq-bloque"></div>'.repeat(n)}</div>`;
}

/**
 * HTML de un aviso de error a partir de un ErrorApi (o Error común).
 * @param {any} err
 */
export function bloqueError(err) {
  const msg = err && (err.mensaje || err.message) ? (err.mensaje || err.message) : 'Error inesperado.';
  const cod = err && err.codigo ? ` <span class="mono">(${esc(err.codigo)})</span>` : '';
  return `<div class="aviso error"><i class="bi bi-exclamation-octagon" aria-hidden="true"></i><div>${esc(msg)}${cod}</div></div>`;
}

/**
 * Anima un número desde 0 hasta su valor (KPIs).
 * @param {HTMLElement} el
 * @param {number} valor
 * @param {number} [ms=900]
 */
export function animarConteo(el, valor, ms = 900) {
  const destino = Number(valor) || 0;
  const reducir = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reducir || destino === 0) { el.textContent = miles(destino); return; }
  const inicio = performance.now();
  const paso = (ahora) => {
    const t = Math.min(1, (ahora - inicio) / ms);
    const suave = 1 - Math.pow(1 - t, 3);
    el.textContent = miles(destino * suave);
    if (t < 1) requestAnimationFrame(paso);
  };
  requestAnimationFrame(paso);
}

/**
 * Convierte un objeto a JSON con colores, escapando cada fragmento.
 * @param {any} obj
 * @returns {string} HTML seguro
 */
export function jsonResaltado(obj) {
  const texto = JSON.stringify(obj, null, 2) ?? 'null';
  return esc(texto).replace(
    /(&quot;(?:\\.|[^&\\]|&(?!quot;))*?&quot;)(\s*:)?|\b(true|false|null)\b|(-?\d+(?:\.\d+)?)/g,
    (m, cadena, dosPuntos, literal, numero) => {
      if (cadena) return dosPuntos ? `<span class="k">${cadena}</span>${dosPuntos}` : `<span class="s">${cadena}</span>`;
      if (literal) return `<span class="l">${literal}</span>`;
      return `<span class="n">${numero}</span>`;
    }
  );
}

/**
 * Saludo según la hora local del navegador.
 * @returns {{texto:string, icono:string}}
 */
export function momentoDelDia() {
  const h = new Date().getHours();
  if (h < 12) return { texto: 'Buenos días', icono: 'sunrise' };
  if (h < 19) return { texto: 'Buenas tardes', icono: 'sun' };
  return { texto: 'Buenas noches', icono: 'moon-stars' };
}

/* ---------- Menús ---------- */

/** Orden de los grupos en la barra lateral. */
const ORDEN_GRUPOS = ['Control', 'Gestión', 'Operación'];

/**
 * Agrupa menús por "grupo" respetando ORDEN_GRUPOS y luego "orden".
 * @param {any[]} menus
 * @returns {Array<[string, any[]]>}
 */
export function agruparMenus(menus) {
  const mapa = new Map();
  [...menus].sort((a, b) => (a.orden ?? 0) - (b.orden ?? 0)).forEach((m) => {
    const g = m.grupo || 'Otros';
    if (!mapa.has(g)) mapa.set(g, []);
    mapa.get(g).push(m);
  });
  const peso = (g) => { const i = ORDEN_GRUPOS.indexOf(g); return i < 0 ? 99 : i; };
  return [...mapa.entries()].sort((a, b) => peso(a[0]) - peso(b[0]));
}
