/* =====================================================================
   vistas/inicio.js — Bienvenida.
   Saludo según la hora, resumen "Tu acceso" (menús y grupos) y tarjetas
   de acceso rápido SOLO a los menús asignados al usuario.
   ===================================================================== */
import { esc, momentoDelDia, agruparMenus } from '../ui.js';
import { claveDeRuta } from '../enrutador.js';

/** Fecha de hoy en texto, sin depender de la configuración regional: "lunes 19 de octubre". */
function hoyTexto() {
  const d = new Date();
  const dias = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
  const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  return `${dias[d.getDay()]} ${d.getDate()} de ${meses[d.getMonth()]}`;
}

/** Total de menús del catálogo semilla (para el "x de y"). */
const TOTAL_CATALOGO = 7;

/**
 * Pinta la vista de inicio.
 * @param {HTMLElement} el contenedor
 * @param {{usuario:any, menus:any[]}} ctx
 */
export async function mostrar(el, ctx) {
  const u = ctx.usuario || {};
  const momento = momentoDelDia();
  const primerNombre = String(u.nombre || u.usuario || '').split(' ')[0];
  const grupos = agruparMenus(ctx.menus || []);
  const total = (ctx.menus || []).length;

  const tarjetas = grupos.map(([grupo, menus]) => `
    <div class="titulo-seccion">${esc(grupo)}</div>
    <div class="rejilla-atajos">
      ${menus.map((m, i) => `
        <a class="tarjeta atajo" href="#/${esc(claveDeRuta(m.ruta))}" style="animation-delay:${i * 50}ms">
          <span class="sello-ico"><i class="bi bi-${esc(m.icono)}" aria-hidden="true"></i></span>
          <div class="flex-grow-1" style="min-width:0">
            <h3>${esc(m.nombre)}</h3>
            <p>${esc(m.descripcion)}</p>
          </div>
          <i class="bi bi-arrow-right flecha" aria-hidden="true"></i>
        </a>`).join('')}
    </div>`).join('');

  el.innerHTML = `
    <section class="bienvenida">
      <span class="momento"><i class="bi bi-${momento.icono}" aria-hidden="true"></i> ${esc(hoyTexto())}</span>
      <h1>${esc(momento.texto)}, ${esc(primerNombre)}</h1>
      <p>Este es su espacio en Atalaya. Solo ve las opciones que el administrador le asignó; cada vez que abre un módulo, el servidor vuelve a verificar su permiso.</p>
      <div class="resumen-acceso" aria-label="Tu acceso">
        <div class="pildora"><b>${total}</b><span>de ${TOTAL_CATALOGO} menús<br>asignados</span></div>
        <div class="pildora"><b>${grupos.length}</b><span>${grupos.length === 1 ? 'grupo' : 'grupos'}<br>${esc(grupos.map((g) => g[0]).join(' · ') || 'sin grupos')}</span></div>
        <div class="pildora"><i class="bi bi-person-badge" style="font-size:22px" aria-hidden="true"></i><span>${esc(u.usuario ? '@' + u.usuario : '')}<br>${esc(u.correo || '')}</span></div>
      </div>
    </section>

    <div class="encabezado mb-0">
      <div><div class="antetitulo">Tu acceso</div><h1>Accesos rápidos</h1><p>Vaya directo a los módulos que tiene habilitados.</p></div>
      <div class="acciones"><a class="btn btn-light" href="#/manual"><i class="bi bi-journal-text" aria-hidden="true"></i> Ver el manual</a></div>
    </div>
    ${total ? tarjetas : `
      <div class="tarjeta mt-3">
        <div class="vacio-bloque"><i class="bi bi-door-closed" aria-hidden="true"></i><b>Aún no tiene menús asignados</b>
        <span>Pida al administrador que le asigne los módulos que necesita desde "Asignación de menús".</span></div>
      </div>`}
  `;
}
