/* =====================================================================
   vistas/sinacceso.js — Pantalla "Sin acceso".
   Se muestra cuando la ruta pedida no está entre los menús del usuario.
   Para demostrar que la seguridad vive en el servidor, llama DE VERDAD
   al endpoint del módulo y enseña el código HTTP y el JSON recibido
   (normalmente 403 ACCESO_DENEGADO, que además queda en la bitácora).
   ===================================================================== */
import { sondear } from '../api.js';
import { esc, jsonResaltado } from '../ui.js';
import { MODULOS } from '../enrutador.js';

/**
 * @param {HTMLElement} el
 * @param {{modulo:any, params:URLSearchParams}} ctx
 */
export async function mostrar(el, ctx) {
  // #/sin-acceso?ruta=usuarios también funciona (enlace directo).
  const modulo = ctx.modulo || MODULOS[ctx.params.get('ruta') || ''] || null;
  const nombre = modulo ? modulo.nombre : 'este módulo';

  el.innerHTML = `
    <div class="sin-acceso">
      <div class="escudo"><i class="bi bi-shield-lock" aria-hidden="true"></i></div>
      <h1>Sin acceso a ${esc(nombre)}</h1>
      <p>Su usuario no tiene asignado el menú <b>${esc(modulo ? modulo.codigo : '—')}</b>. Si lo necesita, solicítelo al administrador.</p>
      ${modulo ? `
      <div class="prueba-servidor">
        <div class="cabeza">
          <i class="bi bi-hdd-network text-primary" aria-hidden="true"></i>
          <p>La interfaz oculta la opción, pero quien decide es el servidor:</p>
          <span class="codigo-http" id="codigo-http"><span class="spinner-border spinner-border-sm" aria-hidden="true"></span></span>
        </div>
        <div class="peticion mono"><span class="metodo">GET</span>${esc(modulo.endpoint)} <span class="suave">· Authorization: Bearer &lt;su token&gt;</span></div>
        <pre class="json" id="respuesta" aria-live="polite">Consultando al servidor…</pre>
      </div>` : ''}
      <div class="d-flex gap-2 justify-content-center mt-4 flex-wrap">
        <a class="btn btn-primary" href="#/inicio"><i class="bi bi-house-door" aria-hidden="true"></i> Volver al inicio</a>
        <a class="btn btn-light" href="#/manual"><i class="bi bi-question-circle" aria-hidden="true"></i> ¿Qué significa esto?</a>
      </div>
    </div>`;

  if (!modulo) return;
  const r = await sondear(modulo.endpoint);
  if (!ctx.vigente()) return;
  const cod = el.querySelector('#codigo-http');
  cod.textContent = r.estado === 0 ? 'Sin conexión' : `HTTP ${r.estado}`;
  cod.classList.toggle('ok', r.estado >= 200 && r.estado < 300);
  el.querySelector('#respuesta').innerHTML = jsonResaltado(r.cuerpo);
}
