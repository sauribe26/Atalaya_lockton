/* =====================================================================
   vistas/clientes.js — Clientes del corredor (menú CLIENTES).
   Listado de GET /api/clientes con búsqueda local y resumen.
   Datos de demostración (ficticios).
   ===================================================================== */
import { esc, fecha, miles, iniciales } from '../ui.js';
import { listado, resumenKpis } from '../tabla.js';

/**
 * @param {HTMLElement} el
 * @param {{vigente:Function}} ctx
 */
export async function mostrar(el, ctx) {
  await listado(el, ctx, {
    antetitulo: 'Operación', titulo: 'Clientes', icono: 'building',
    descripcion: 'Empresas aseguradas a través del corredor.',
    endpoint: '/api/clientes', placeholder: 'Buscar por NIT, razón social, sector o ciudad',
    texto: (c) => `${c.nit} ${c.razonSocial} ${c.sector} ${c.ciudad}`,
    orden: (a, b) => String(a.razonSocial).localeCompare(String(b.razonSocial)),
    resumen: (filas) => resumenKpis([
      { nombre: 'Clientes', valor: miles(filas.length), icono: 'building', tono: 'tinta' },
      { nombre: 'Pólizas vigentes', valor: miles(filas.reduce((s, c) => s + (Number(c.polizasVigentes) || 0), 0)), icono: 'file-earmark-check', tono: 'verde' },
      { nombre: 'Sectores', valor: miles(new Set(filas.map((c) => c.sector)).size), icono: 'diagram-2' },
      { nombre: 'Ciudades', valor: miles(new Set(filas.map((c) => c.ciudad)).size), icono: 'geo-alt' }
    ]),
    columnas: [
      { titulo: 'Cliente', celda: (c) => `<div class="persona"><span class="sello-ico" style="width:38px;height:38px;font-size:13px;font-weight:700">${esc(iniciales(c.razonSocial))}</span><div><b>${esc(c.razonSocial)}</b><small class="mono">NIT ${esc(c.nit)}</small></div></div>` },
      { titulo: 'Sector', celda: (c) => `<span class="etiqueta">${esc(c.sector)}</span>` },
      { titulo: 'Ciudad', celda: (c) => `<i class="bi bi-geo-alt suave" aria-hidden="true"></i> ${esc(c.ciudad)}` },
      { titulo: 'Cliente desde', celda: (c) => `<span class="suave">${esc(fecha(c.fechaAlta))}</span>` },
      { titulo: 'Pólizas vigentes', clase: 'der', celda: (c) => `<span class="semaforo ${Number(c.polizasVigentes) ? 'ok' : 'neutro'}">${miles(c.polizasVigentes)}</span>` }
    ]
  });
}
