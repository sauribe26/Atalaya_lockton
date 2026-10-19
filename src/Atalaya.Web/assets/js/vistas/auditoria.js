/* =====================================================================
   vistas/auditoria.js — Bitácora de accesos (menú AUDITORIA).
   Línea de tiempo de eventos (GET /api/auditoria?evento=&limite=200),
   filtro por tipo de evento con chips, color e ícono por tipo y
   refresco automático opcional cada 15 segundos.
   ===================================================================== */
import { api } from '../api.js';
import { esc, fechaHora, bloqueError, vacio } from '../ui.js';

/** Presentación de cada tipo de evento del contrato. */
const EVENTOS = {
  LOGIN_OK:           { nombre: 'Ingreso exitoso',     icono: 'box-arrow-in-right', clase: 'ev-ok',       color: '#15803d' },
  LOGIN_FALLIDO:      { nombre: 'Ingreso fallido',     icono: 'x-circle',           clase: 'ev-fallo',    color: '#b45309' },
  LOGIN_BLOQUEADO:    { nombre: 'Usuario bloqueado',   icono: 'lock',               clase: 'ev-bloqueo',  color: '#b91c1c' },
  ACCESO_DENEGADO:    { nombre: 'Acceso denegado',     icono: 'shield-x',           clase: 'ev-denegado', color: '#be123c' },
  USUARIO_CREADO:     { nombre: 'Usuario creado',      icono: 'person-plus',        clase: 'ev-gestion',  color: '#1f7a94' },
  USUARIO_ESTADO:     { nombre: 'Cambio de estado',    icono: 'toggle-on',          clase: 'ev-gestion',  color: '#1f7a94' },
  MENUS_ACTUALIZADOS: { nombre: 'Menús actualizados',  icono: 'diagram-3',          clase: 'ev-menus',    color: '#6d28d9' }
};

/**
 * @param {HTMLElement} el
 * @param {{vigente:Function}} ctx
 * @returns {Promise<Function>} limpieza (detiene el refresco automático)
 */
export async function mostrar(el, ctx) {
  let filtro = '';
  let temporizador = null;
  let consulta = 0;

  el.innerHTML = `
    <div class="encabezado">
      <div><div class="antetitulo">Control</div><h1>Bitácora de accesos</h1><p>Todo ingreso, rechazo y cambio de permisos queda registrado por el servidor.</p></div>
      <div class="acciones">
        <div class="form-check form-switch m-0 refresco">
          <input class="form-check-input" type="checkbox" role="switch" id="auto">
          <label class="form-check-label" for="auto">Actualizar cada 15 s</label>
          <span class="pulso d-none" id="pulso" aria-hidden="true"></span>
        </div>
        <button class="btn btn-light" id="btn-recargar" type="button"><i class="bi bi-arrow-clockwise" aria-hidden="true"></i> Actualizar</button>
      </div>
    </div>
    <div class="barra-filtros">
      <div class="chips" role="group" aria-label="Filtrar por evento">
        <button type="button" class="chip-filtro activo" data-evento="" aria-pressed="true">Todos</button>
        ${Object.entries(EVENTOS).map(([k, v]) => `<button type="button" class="chip-filtro" data-evento="${k}" aria-pressed="false"><span class="color" style="background:${v.color}"></span>${esc(v.nombre)}</button>`).join('')}
      </div>
      <span class="contador" id="contador" aria-live="polite"></span>
    </div>
    <div id="lista"><div class="tarjeta">${'<div class="esqueleto esq-fila"></div>'.repeat(6)}</div></div>`;

  const lista = el.querySelector('#lista');

  async function cargar() {
    const mio = ++consulta;
    try {
      const r = await api.get(`/api/auditoria?limite=200${filtro ? `&evento=${encodeURIComponent(filtro)}` : ''}`);
      if (mio !== consulta || !ctx.vigente()) return;
      pintar(Array.isArray(r) ? r : []);
    } catch (err) {
      if (mio === consulta && ctx.vigente()) lista.innerHTML = bloqueError(err);
    }
  }

  function pintar(eventos) {
    el.querySelector('#contador').textContent = `${eventos.length} evento(s)`;
    if (!eventos.length) {
      lista.innerHTML = `<div class="tarjeta">${vacio('journal-x', 'No hay eventos para este filtro')}</div>`;
      return;
    }
    lista.innerHTML = `<ol class="linea-tiempo">${eventos.map((ev, i) => {
      const t = EVENTOS[ev.evento] || { nombre: ev.evento, icono: 'dot', clase: 'ev-gestion' };
      return `<li class="evento ${t.clase}" style="animation-delay:${Math.min(i, 15) * 20}ms">
        <span class="icono"><i class="bi bi-${t.icono}" aria-hidden="true"></i></span>
        <div class="cuerpo">
          <div class="fila1"><span class="tipo">${esc(t.nombre)}</span><b>${esc(ev.usuario || 'desconocido')}</b>
            <time datetime="${esc(ev.fecha)}">${esc(fechaHora(ev.fecha))}</time></div>
          <div class="fila2">${[
            ev.detalle ? esc(ev.detalle) : '',
            ev.recurso ? `<span class="mono">${esc(ev.recurso)}</span>` : '',
            ev.ip ? `<span class="mono">IP ${esc(ev.ip)}</span>` : ''
          ].filter(Boolean).join(' <span class="suave">·</span> ') || '<span class="suave">Sin detalle</span>'}</div>
        </div></li>`;
    }).join('')}</ol>`;
  }

  el.querySelector('.chips').addEventListener('click', (e) => {
    const b = e.target.closest('.chip-filtro');
    if (!b) return;
    filtro = b.dataset.evento;
    el.querySelectorAll('.chip-filtro').forEach((c) => { const a = c === b; c.classList.toggle('activo', a); c.setAttribute('aria-pressed', String(a)); });
    cargar();
  });
  el.querySelector('#btn-recargar').addEventListener('click', cargar);
  el.querySelector('#auto').addEventListener('change', (e) => {
    clearInterval(temporizador);
    temporizador = e.target.checked ? setInterval(() => { if (ctx.vigente()) cargar(); }, 15000) : null;
    el.querySelector('#pulso').classList.toggle('d-none', !e.target.checked);
  });

  await cargar();
  return () => clearInterval(temporizador);
}
