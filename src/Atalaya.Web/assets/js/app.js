/* =====================================================================
   app.js — Arranque del shell (index.html).
   1. Verifica la sesión y consulta GET /api/auth/yo (401 → login).
   2. Arma la barra lateral SOLO con los menús que devolvió el servidor,
      agrupados por "grupo" y ordenados por "orden" (+ Inicio y Manual).
   3. Barra superior: título del módulo, migas, buscador Ctrl+K, avatar.
   4. Barra lateral colapsable a riel (PC/tablet) o cajón (celular).
   5. Inicia el enrutador por hash con su guardia de menús.
   ===================================================================== */
import { api } from './api.js';
import { obtenerUsuario, actualizarUsuario, cerrarSesion, haySesion } from './sesion.js';
import { esc, iniciales, normalizar, aviso, agruparMenus } from './ui.js';
import { crearEnrutador, claveDeRuta } from './enrutador.js';

const estado = {
  usuario: obtenerUsuario(),
  menus: []
};

const $ = (id) => document.getElementById(id);
const app = $('app');
const lateral = $('lateral');
const velo = $('velo');
const esCelular = () => window.matchMedia('(max-width: 767px)').matches;

/* ---------- Barra lateral ---------- */

/** Enlace de la barra lateral (todo escapado). */
function enlace(href, icono, nombre, clave, retraso) {
  return `<a href="${esc(href)}" data-clave="${esc(clave)}" title="${esc(nombre)}" style="animation-delay:${retraso}ms">
    <i class="bi bi-${esc(icono)}" aria-hidden="true"></i><span>${esc(nombre)}</span></a>`;
}

/** Pinta la barra lateral con los menús del usuario. */
function pintarLateral() {
  let n = 0;
  let html = `<div class="grupo"><div class="titulo-grupo">General</div>
    ${enlace('#/inicio', 'house-door', 'Inicio', 'inicio', n++ * 30)}</div>`;
  const grupos = agruparMenus(estado.menus);
  if (!grupos.length) {
    html += '<div class="sin-menus"><i class="bi bi-info-circle" aria-hidden="true"></i> Aún no tiene menús asignados. Solicite acceso al administrador.</div>';
  }
  grupos.forEach(([grupo, menus]) => {
    html += `<div class="grupo"><div class="titulo-grupo">${esc(grupo)}</div>
      ${menus.map((m) => enlace(`#/${claveDeRuta(m.ruta)}`, m.icono, m.nombre, claveDeRuta(m.ruta), n++ * 30)).join('')}</div>`;
  });
  html += `<div class="grupo"><div class="titulo-grupo">Ayuda</div>
    ${enlace('#/manual', 'journal-text', 'Manual de uso', 'manual', n++ * 30)}</div>`;
  $('navegacion').innerHTML = html;
  marcarActivo();
}

/** Resalta en la barra lateral el ítem de la ruta actual. */
function marcarActivo(clave) {
  const actual = clave || window.location.hash.replace(/^#\/?/, '').split('?')[0] || 'inicio';
  document.querySelectorAll('#navegacion a').forEach((a) => {
    const activo = a.dataset.clave === actual;
    a.classList.toggle('activo', activo);
    if (activo) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });
}

/* ---------- Riel / cajón ---------- */
function leerRiel() { try { return localStorage.getItem('atalaya.riel') === '1'; } catch { return false; } }
function guardarRiel(v) { try { localStorage.setItem('atalaya.riel', v ? '1' : '0'); } catch { /* no disponible */ } }

function alternarRiel() {
  const riel = !app.classList.contains('riel');
  app.classList.toggle('riel', riel);
  guardarRiel(riel);
  $('btn-menu').setAttribute('aria-expanded', String(!riel));
}
function abrirCajon(abrir) {
  lateral.classList.toggle('abierta', abrir);
  velo.classList.toggle('visible', abrir);
  $('btn-menu').setAttribute('aria-expanded', String(abrir));
}

app.classList.toggle('riel', leerRiel());
$('btn-menu').addEventListener('click', () => (esCelular() ? abrirCajon(!lateral.classList.contains('abierta')) : alternarRiel()));
$('pestana').addEventListener('click', alternarRiel);
velo.addEventListener('click', () => abrirCajon(false));
$('navegacion').addEventListener('click', (e) => { if (e.target.closest('a') && esCelular()) abrirCajon(false); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && lateral.classList.contains('abierta')) abrirCajon(false); });

/* ---------- Barra superior ---------- */

/** Actualiza título, ícono y migas según la ruta. */
function alNavegar(info) {
  $('titulo-modulo').textContent = info.nombre;
  $('titulo-ico').className = `bi bi-${info.icono}`;
  document.title = `${info.nombre} · Atalaya`;
  const partes = ['<a href="#/inicio">Atalaya</a>'];
  if (info.grupo) partes.push(`<span>${esc(info.grupo)}</span>`);
  if (info.ruta !== 'inicio') partes.push(`<span class="actual">${esc(info.nombre)}${info.permitido ? '' : ' · sin acceso'}</span>`);
  else partes.push('<span class="actual">Inicio</span>');
  $('migas').innerHTML = partes.join('<span class="sep" aria-hidden="true">/</span>');
  marcarActivo(info.permitido ? info.ruta : '__ninguno__');
  window.scrollTo({ top: 0 });
}

/** Pinta los datos del usuario en el avatar y su menú. */
function pintarUsuario() {
  const u = estado.usuario || {};
  $('avatar').textContent = iniciales(u.nombre || u.usuario);
  $('quien-nombre').textContent = u.nombre || '—';
  $('quien-correo').textContent = u.correo || '';
  $('quien-usuario').textContent = u.usuario ? `@${u.usuario}` : '';
}
$('btn-salir').addEventListener('click', () => cerrarSesion('salir'));

/* ---------- Paleta Ctrl+K ---------- */
const paletaEl = $('paleta');
const paletaTexto = $('paleta-texto');
const paletaRes = $('paleta-resultados');
let paleta = null;
let seleccion = 0;
let candidatos = [];

/** Lista de destinos navegables: los menús del usuario + Inicio + Manual. */
function destinos() {
  return [
    { ruta: 'inicio', nombre: 'Inicio', descripcion: 'Bienvenida y accesos rápidos', icono: 'house-door', grupo: 'General' },
    ...agruparMenus(estado.menus).flatMap(([, ms]) => ms.map((m) => ({
      ruta: claveDeRuta(m.ruta), nombre: m.nombre, descripcion: m.descripcion, icono: m.icono, grupo: m.grupo
    }))),
    { ruta: 'manual', nombre: 'Manual de uso', descripcion: 'Guía del aplicativo paso a paso', icono: 'journal-text', grupo: 'Ayuda' }
  ];
}

function pintarPaleta() {
  const q = normalizar(paletaTexto.value.trim());
  candidatos = destinos().filter((d) => !q || normalizar(`${d.nombre} ${d.descripcion} ${d.grupo}`).includes(q));
  seleccion = Math.min(seleccion, Math.max(0, candidatos.length - 1));
  paletaRes.innerHTML = candidatos.length
    ? candidatos.map((d, i) => `<a href="#/${esc(d.ruta)}" class="res ${i === seleccion ? 'sel' : ''}" role="option" aria-selected="${i === seleccion}" data-i="${i}">
        <span class="sello-ico"><i class="bi bi-${esc(d.icono)}" aria-hidden="true"></i></span>
        <span><b>${esc(d.nombre)}</b><small>${esc(d.descripcion || '')}</small></span>
        <span class="grupo">${esc(d.grupo || '')}</span></a>`).join('')
    : '<div class="vacio-bloque" style="padding:28px"><i class="bi bi-search" aria-hidden="true"></i><b>Sin coincidencias</b><span>Solo puede buscar entre los menús que tiene asignados.</span></div>';
}

function abrirPaleta() {
  if (!window.bootstrap) return;
  paleta = paleta || new window.bootstrap.Modal(paletaEl);
  paletaTexto.value = '';
  seleccion = 0;
  pintarPaleta();
  paleta.show();
}
paletaEl.addEventListener('shown.bs.modal', () => paletaTexto.focus());
paletaTexto.addEventListener('input', () => { seleccion = 0; pintarPaleta(); });
paletaTexto.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowDown') { e.preventDefault(); seleccion = Math.min(candidatos.length - 1, seleccion + 1); pintarPaleta(); }
  else if (e.key === 'ArrowUp') { e.preventDefault(); seleccion = Math.max(0, seleccion - 1); pintarPaleta(); }
  else if (e.key === 'Enter' && candidatos[seleccion]) { e.preventDefault(); window.location.hash = `#/${candidatos[seleccion].ruta}`; paleta.hide(); }
});
paletaRes.addEventListener('click', (e) => { if (e.target.closest('a')) paleta.hide(); });
$('btn-buscar').addEventListener('click', abrirPaleta);
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); abrirPaleta(); }
});

/* ---------- Datos del servidor ---------- */

/**
 * Vuelve a pedir /api/auth/yo y redibuja la barra lateral.
 * Se usa al arrancar y cuando el usuario se cambia sus propios menús.
 */
async function refrescarMenus() {
  const yo = await api.get('/api/auth/yo');
  estado.usuario = yo.usuario || estado.usuario;
  estado.menus = Array.isArray(yo.menus) ? yo.menus : [];
  actualizarUsuario(estado.usuario);
  pintarUsuario();
  pintarLateral();
  return estado.menus;
}

const enrutador = crearEnrutador({
  contenedor: $('contenido'),
  contexto: () => ({ usuario: estado.usuario, menus: estado.menus, refrescarMenus, ir: (r) => enrutador.ir(r) }),
  alNavegar
});

/** Arranque. */
(async function iniciar() {
  if (!haySesion()) { cerrarSesion(); return; }
  pintarUsuario();
  try {
    await refrescarMenus();
  } catch (err) {
    if (err && err.estado === 401) return; // api.js ya redirigió al login
    $('navegacion').innerHTML = '<div class="sin-menus">No fue posible cargar su menú.</div>';
    $('contenido').innerHTML = `<div class="aviso error"><i class="bi bi-wifi-off" aria-hidden="true"></i><div>No fue posible comunicarse con el servidor: ${esc(err && err.mensaje)} <button type="button" class="btn btn-sm btn-light ms-2" id="btn-reintentar">Reintentar</button></div></div>`;
    $('btn-reintentar').addEventListener('click', () => window.location.reload());
    aviso('No fue posible cargar su perfil.', 'error');
    return;
  }
  enrutador.iniciar();
})();
