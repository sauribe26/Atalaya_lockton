/* =====================================================================
   tabla.js — Vista genérica de listado con búsqueda local.
   La usan Clientes, Pólizas y Siniestros: encabezado, mini-resumen,
   chips de estado, buscador sin tildes, tabla que en celular se apila
   como tarjetas, esqueleto de carga y estado vacío.
   Las funciones "celda" deben devolver HTML ya escapado con esc().
   ===================================================================== */
import { api } from './api.js';
import { esc, normalizar, debounce, esqueletoFilas, bloqueError, vacio } from './ui.js';

/**
 * Pinta un listado completo.
 * @param {HTMLElement} el contenedor de la vista
 * @param {{vigente:Function}} ctx contexto del enrutador
 * @param {{
 *   antetitulo:string, titulo:string, descripcion:string, icono:string,
 *   endpoint:string, placeholder:string,
 *   columnas: Array<{titulo:string, clase?:string, celda:(fila:any)=>string}>,
 *   texto: (fila:any)=>string,
 *   estados?: Array<{valor:string, nombre:string}>, campoEstado?:string,
 *   resumen?: (filas:any[])=>string,
 *   orden?: (a:any,b:any)=>number
 * }} cfg
 */
export async function listado(el, ctx, cfg) {
  let filas = [];
  let estado = '';

  el.innerHTML = `
    <div class="encabezado">
      <div><div class="antetitulo">${esc(cfg.antetitulo)}</div><h1>${esc(cfg.titulo)}</h1><p>${esc(cfg.descripcion)}</p></div>
    </div>
    <div id="resumen"></div>
    <div class="barra-filtros">
      <div class="buscador"><i class="bi bi-search" aria-hidden="true"></i>
        <input class="form-control" id="buscar" type="search" placeholder="${esc(cfg.placeholder)}" aria-label="${esc(cfg.placeholder)}"></div>
      ${cfg.estados ? `<div class="chips" role="group" aria-label="Filtrar por estado">
        <button type="button" class="chip-filtro activo" data-estado="" aria-pressed="true">Todos</button>
        ${cfg.estados.map((s) => `<button type="button" class="chip-filtro" data-estado="${esc(s.valor)}" aria-pressed="false">${esc(s.nombre)}</button>`).join('')}
      </div>` : ''}
      <span class="contador" id="contador" aria-live="polite"></span>
    </div>
    <div id="lista">${esqueletoFilas(6)}</div>`;

  const lista = el.querySelector('#lista');

  function pintar() {
    const q = normalizar(el.querySelector('#buscar').value.trim());
    const visibles = filas.filter((f) => (!estado || f[cfg.campoEstado] === estado) && (!q || normalizar(cfg.texto(f)).includes(q)));
    el.querySelector('#contador').textContent = `${visibles.length} de ${filas.length}`;
    if (!visibles.length) {
      lista.innerHTML = `<div class="tarjeta">${filas.length ? vacio('search', 'Sin coincidencias', 'Pruebe con otra búsqueda o filtro.') : vacio(cfg.icono, 'Aún no hay registros')}</div>`;
      return;
    }
    lista.innerHTML = `<div class="tabla apilable"><div class="envoltura"><table>
      <thead><tr>${cfg.columnas.map((c) => `<th class="${c.clase || ''}">${esc(c.titulo)}</th>`).join('')}</tr></thead>
      <tbody>${visibles.map((f) => `<tr>${cfg.columnas.map((c, i) => `<td class="${c.clase || ''}" ${i ? `data-etq="${esc(c.titulo)}"` : ''}>${c.celda(f)}</td>`).join('')}</tr>`).join('')}</tbody>
    </table></div></div>`;
  }

  try {
    const r = await api.get(cfg.endpoint);
    if (!ctx.vigente()) return;
    filas = Array.isArray(r) ? r : [];
    if (cfg.orden) filas.sort(cfg.orden);
  } catch (err) {
    if (ctx.vigente()) lista.innerHTML = bloqueError(err);
    return;
  }
  if (cfg.resumen) el.querySelector('#resumen').innerHTML = cfg.resumen(filas);
  el.querySelector('#buscar').addEventListener('input', debounce(pintar, 150));
  const chips = el.querySelector('.chips');
  if (chips) chips.addEventListener('click', (e) => {
    const b = e.target.closest('.chip-filtro');
    if (!b) return;
    estado = b.dataset.estado;
    chips.querySelectorAll('.chip-filtro').forEach((c) => { const a = c === b; c.classList.toggle('activo', a); c.setAttribute('aria-pressed', String(a)); });
    pintar();
  });
  pintar();
}

/**
 * Tarjetas pequeñas de resumen (para encima de la tabla).
 * @param {Array<{nombre:string, valor:string, icono:string, tono?:string}>} items valor ya formateado
 */
export function resumenKpis(items) {
  return `<div class="kpis">${items.map((k, i) => `
    <div class="kpi ${k.tono || ''}" style="animation-delay:${i * 40}ms">
      <span class="sello-ico"><i class="bi bi-${esc(k.icono)}" aria-hidden="true"></i></span>
      <div class="datos"><span>${esc(k.nombre)}</span><b class="${String(k.valor).length > 9 ? 'largo' : ''}">${esc(k.valor)}</b></div>
    </div>`).join('')}</div>`;
}
