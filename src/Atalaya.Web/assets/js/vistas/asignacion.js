/* =====================================================================
   vistas/asignacion.js — Asignación de menús (menú ASIGNACION).
   · Izquierda: lista de usuarios con buscador local (GET /api/users).
   · Derecha: catálogo de menús (GET /api/menus) agrupado por "grupo",
     como tarjetas-interruptor; marca los asignados (GET /api/users/{id}/menus).
   · Cambios pendientes con diff (+agregados / −retirados) antes de guardar
     con PUT /api/users/{id}/menus. "Marcar todo"/"Quitar todo" por grupo.
   · 409 AUTOBLOQUEO: el servidor impide quitarse a sí mismo ASIGNACION.
   · Si el usuario editado es el autenticado, se refresca la barra lateral.
   ===================================================================== */
import { api } from '../api.js';
import { esc, iniciales, normalizar, aviso, procesando, bloqueError, vacio, agruparMenus } from '../ui.js';

/**
 * @param {HTMLElement} el
 * @param {{usuario:any, params:URLSearchParams, refrescarMenus:Function, vigente:Function}} ctx
 */
export async function mostrar(el, ctx) {
  const estado = {
    usuarios: [],
    catalogo: [],
    seleccionado: null,   // usuario elegido
    originales: new Set(),// ids de menú asignados en el servidor
    marcados: new Set()   // ids marcados en pantalla
  };

  el.innerHTML = `
    <div class="encabezado">
      <div><div class="antetitulo">Gestión</div><h1>Asignación de menús</h1><p>Elija un usuario y encienda los menús que debe ver. Los cambios aplican de inmediato en el servidor.</p></div>
    </div>
    <div class="asignacion">
      <aside class="tarjeta lista-usuarios" aria-label="Usuarios">
        <div class="buscador" style="max-width:none;min-width:0"><i class="bi bi-search" aria-hidden="true"></i>
          <input class="form-control" id="filtro-usuarios" type="search" placeholder="Buscar usuario" aria-label="Buscar usuario"></div>
        <div class="items" id="items-usuarios" role="listbox" aria-label="Seleccione un usuario">${'<div class="esqueleto esq-fila"></div>'.repeat(4)}</div>
      </aside>
      <section id="panel-menus" aria-live="polite">
        <div class="tarjeta">${vacio('hand-index', 'Seleccione un usuario', 'Sus menús aparecerán aquí.')}</div>
      </section>
    </div>`;

  const items = el.querySelector('#items-usuarios');
  const panel = el.querySelector('#panel-menus');

  try {
    const [usuarios, catalogo] = await Promise.all([api.get('/api/users'), api.get('/api/menus')]);
    if (!ctx.vigente()) return;
    estado.usuarios = usuarios || [];
    estado.catalogo = catalogo || [];
  } catch (err) {
    if (ctx.vigente()) { items.innerHTML = ''; panel.innerHTML = bloqueError(err); }
    return;
  }

  const hayCambios = () => diferencias().agregados.length + diferencias().retirados.length > 0;

  function diferencias() {
    const agregados = [...estado.marcados].filter((id) => !estado.originales.has(id));
    const retirados = [...estado.originales].filter((id) => !estado.marcados.has(id));
    return { agregados, retirados };
  }

  function pintarUsuarios() {
    const q = normalizar(el.querySelector('#filtro-usuarios').value);
    const lista = estado.usuarios.filter((u) => !q || normalizar(`${u.nombre} ${u.usuario} ${u.correo}`).includes(q));
    items.innerHTML = lista.length ? lista.map((u) => `
      <button type="button" class="item-usuario ${estado.seleccionado && estado.seleccionado.id === u.id ? 'activo' : ''}" data-id="${Number(u.id)}" role="option"
        aria-selected="${estado.seleccionado && estado.seleccionado.id === u.id ? 'true' : 'false'}">
        <span class="iniciales ${u.activo ? '' : 'off'}">${esc(iniciales(u.nombre))}</span>
        <span class="txt"><b>${esc(u.nombre)}</b><small>@${esc(u.usuario)}${u.activo ? '' : ' · inactivo'}</small></span>
        <span class="cuantos" title="Menús asignados">${Number(u.totalMenus) || 0}</span>
      </button>`).join('') : `<div class="suave p-3 text-center">Sin coincidencias</div>`;
  }

  async function seleccionar(id) {
    if (estado.seleccionado && estado.seleccionado.id === id) return;
    if (hayCambios() && !window.confirm('Tiene cambios sin guardar. ¿Desea descartarlos?')) return;
    const u = estado.usuarios.find((x) => x.id === id);
    if (!u) return;
    estado.seleccionado = u;
    history.replaceState(null, '', `#/asignacion?usuario=${id}`);
    pintarUsuarios();
    panel.innerHTML = `<div class="tarjeta">${'<div class="esqueleto esq-fila"></div>'.repeat(5)}</div>`;
    try {
      const asignados = await api.get(`/api/users/${id}/menus`);
      if (!ctx.vigente() || estado.seleccionado.id !== id) return;
      estado.originales = new Set((asignados || []).map((m) => m.id));
      estado.marcados = new Set(estado.originales);
      pintarMenus();
    } catch (err) {
      panel.innerHTML = bloqueError(err);
    }
  }

  function pintarMenus() {
    const u = estado.seleccionado;
    const grupos = agruparMenus(estado.catalogo);
    const { agregados, retirados } = diferencias();
    const esYo = ctx.usuario && u.id === ctx.usuario.id;
    panel.innerHTML = `
      <div class="tarjeta mb-3 d-flex align-items-center gap-3 flex-wrap">
        <span class="iniciales grande ${u.activo ? '' : 'off'}">${esc(iniciales(u.nombre))}</span>
        <div class="flex-grow-1" style="min-width:0"><h2 class="m-0">${esc(u.nombre)}</h2>
          <span class="suave">@${esc(u.usuario)} · ${esc(u.correo)}</span></div>
        <span class="semaforo ${u.activo ? 'ok' : 'neutro'}">${u.activo ? 'Activo' : 'Inactivo'}</span>
        <span class="etiqueta acento"><b id="total-marcados">${estado.marcados.size}</b> de ${estado.catalogo.length} menús</span>
      </div>
      ${esYo ? '<div class="aviso info mb-3 mt-0"><i class="bi bi-person-exclamation" aria-hidden="true"></i><div>Está editando <b>sus propios menús</b>. Al guardar, su barra lateral se actualizará. El servidor no le permitirá quitarse "Asignación de menús".</div></div>' : ''}
      ${!u.activo ? '<div class="aviso alerta mb-3 mt-0"><i class="bi bi-person-slash" aria-hidden="true"></i><div>Este usuario está inactivo: aunque tenga menús, no podrá ingresar hasta que lo activen.</div></div>' : ''}
      ${grupos.map(([grupo, menus]) => `
        <div class="grupo-menus">
          <div class="cabeza"><h3>${esc(grupo)}</h3><span class="linea"></span>
            <button type="button" class="btn btn-sm btn-light" data-grupo="${esc(grupo)}" data-accion="todo">Marcar todo</button>
            <button type="button" class="btn btn-sm btn-light" data-grupo="${esc(grupo)}" data-accion="nada">Quitar todo</button></div>
          <div class="rejilla-menus">
            ${menus.map((m) => {
              const marcado = estado.marcados.has(m.id);
              const cambio = marcado && !estado.originales.has(m.id) ? '<span class="cambio mas">+ nuevo</span>'
                : (!marcado && estado.originales.has(m.id) ? '<span class="cambio menos">− se retira</span>' : '');
              return `<label class="tarjeta-menu ${marcado ? 'marcado' : ''}">
                <input type="checkbox" data-id="${Number(m.id)}" ${marcado ? 'checked' : ''} aria-label="${esc(m.nombre)}">
                ${cambio}
                <span class="sello-ico"><i class="bi bi-${esc(m.icono)}" aria-hidden="true"></i></span>
                <span class="txt"><b>${esc(m.nombre)}</b><small>${esc(m.descripcion)}</small></span>
                <span class="interruptor" aria-hidden="true"></span>
              </label>`;
            }).join('')}
          </div>
        </div>`).join('')}
      ${agregados.length + retirados.length ? `
        <div class="barra-guardar" role="region" aria-label="Cambios pendientes">
          <i class="bi bi-pencil-square" aria-hidden="true"></i>
          <div class="diff"><b>${agregados.length + retirados.length} cambio(s) pendiente(s):</b>
            ${agregados.length ? `<span class="mas">+${agregados.length} ${esc(nombres(agregados))}</span>` : ''}
            ${retirados.length ? `<span class="menos">−${retirados.length} ${esc(nombres(retirados))}</span>` : ''}</div>
          <button type="button" class="btn btn-light btn-sm" id="btn-descartar">Descartar</button>
          <button type="button" class="btn btn-primary btn-sm" id="btn-guardar"><i class="bi bi-check2" aria-hidden="true"></i> Guardar cambios</button>
        </div>` : ''}`;
  }

  const nombres = (ids) => `(${ids.map((id) => (estado.catalogo.find((m) => m.id === id) || {}).nombre).filter(Boolean).join(', ')})`;

  async function guardar() {
    const u = estado.seleccionado;
    procesando(true, 'Guardando menús…');
    try {
      const r = await api.put(`/api/users/${u.id}/menus`, { menuIds: [...estado.marcados] });
      const menus = (r && r.menus) || [];
      estado.originales = new Set(menus.length || estado.marcados.size === 0 ? menus.map((m) => m.id) : estado.marcados);
      estado.marcados = new Set(estado.originales);
      u.totalMenus = estado.originales.size;
      aviso(`Menús guardados: +${r && r.agregados != null ? r.agregados : 0} agregados, −${r && r.retirados != null ? r.retirados : 0} retirados.`, 'ok');
      pintarUsuarios();
      pintarMenus();
      if (ctx.usuario && u.id === ctx.usuario.id) {
        await ctx.refrescarMenus();
        aviso('Su barra lateral se actualizó con sus nuevos menús.', 'info');
      }
    } catch (err) {
      if (err.codigo === 'AUTOBLOQUEO') {
        aviso('No puede quitarse a sí mismo "Asignación de menús": quedaría sin forma de administrar accesos.', 'error');
        const asig = estado.catalogo.find((m) => m.codigo === 'ASIGNACION');
        if (asig) { estado.marcados.add(asig.id); pintarMenus(); }
      } else {
        aviso(err.mensaje || 'No fue posible guardar.', 'error');
      }
    } finally {
      procesando(false);
    }
  }

  // Eventos.
  el.querySelector('#filtro-usuarios').addEventListener('input', pintarUsuarios);
  items.addEventListener('click', (e) => { const b = e.target.closest('.item-usuario'); if (b) seleccionar(Number(b.dataset.id)); });
  panel.addEventListener('change', (e) => {
    const c = e.target.closest('input[type=checkbox][data-id]');
    if (!c) return;
    const id = Number(c.dataset.id);
    if (c.checked) estado.marcados.add(id); else estado.marcados.delete(id);
    pintarMenus();
    const nuevo = panel.querySelector(`input[data-id="${id}"]`);
    if (nuevo) nuevo.focus();
  });
  panel.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-grupo]');
    if (b) {
      estado.catalogo.filter((m) => (m.grupo || 'Otros') === b.dataset.grupo)
        .forEach((m) => (b.dataset.accion === 'todo' ? estado.marcados.add(m.id) : estado.marcados.delete(m.id)));
      pintarMenus();
      return;
    }
    if (e.target.closest('#btn-descartar')) { estado.marcados = new Set(estado.originales); pintarMenus(); }
    if (e.target.closest('#btn-guardar')) guardar();
  });

  pintarUsuarios();
  const pre = Number(ctx.params.get('usuario'));
  if (pre && estado.usuarios.some((u) => u.id === pre)) await seleccionar(pre);

  // Aviso del navegador si sale de la página con cambios sin guardar.
  const antesDeSalir = (e) => { if (hayCambios()) { e.preventDefault(); e.returnValue = ''; } };
  window.addEventListener('beforeunload', antesDeSalir);
  return () => window.removeEventListener('beforeunload', antesDeSalir);
}
