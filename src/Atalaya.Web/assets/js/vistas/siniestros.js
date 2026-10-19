/* =====================================================================
   vistas/siniestros.js — Siniestros (menú SINIESTROS).
   Listado de GET /api/siniestros con búsqueda local, chips por estado
   y valores reclamados en pesos con punto de miles fijo.
   ===================================================================== */
import { esc, fecha, pesos, miles } from '../ui.js';
import { listado, resumenKpis } from '../tabla.js';

const ESTADOS = {
  ABIERTO: { nombre: 'Abierto', clase: 'info' },
  EN_AJUSTE: { nombre: 'En ajuste', clase: 'alerta' },
  PAGADO: { nombre: 'Pagado', clase: 'ok' },
  OBJETADO: { nombre: 'Objetado', clase: 'error' }
};

/**
 * @param {HTMLElement} el
 * @param {{vigente:Function}} ctx
 */
export async function mostrar(el, ctx) {
  await listado(el, ctx, {
    antetitulo: 'Operación', titulo: 'Siniestros', icono: 'exclamation-diamond',
    descripcion: 'Reclamaciones avisadas sobre las pólizas de los clientes.',
    endpoint: '/api/siniestros', placeholder: 'Buscar por número, póliza, cliente o descripción',
    texto: (s) => `${s.numero} ${s.poliza} ${s.cliente} ${s.descripcion}`,
    estados: Object.entries(ESTADOS).map(([valor, v]) => ({ valor, nombre: v.nombre })),
    campoEstado: 'estado',
    orden: (a, b) => String(b.fechaAviso).localeCompare(String(a.fechaAviso)),
    resumen: (f) => {
      const total = f.reduce((s, x) => s + (Number(x.valorReclamado) || 0), 0);
      const tramite = f.filter((x) => x.estado === 'ABIERTO' || x.estado === 'EN_AJUSTE').length;
      return resumenKpis([
        { nombre: 'Siniestros', valor: miles(f.length), icono: 'exclamation-diamond', tono: 'tinta' },
        { nombre: 'Valor reclamado', valor: pesos(total), icono: 'cash-coin' },
        { nombre: 'En trámite', valor: miles(tramite), icono: 'hourglass-split', tono: 'ambar' },
        { nombre: 'Pagados', valor: miles(f.filter((x) => x.estado === 'PAGADO').length), icono: 'check2-circle', tono: 'verde' }
      ]);
    },
    columnas: [
      { titulo: 'Siniestro', celda: (s) => `<div><b class="tinta mono">${esc(s.numero)}</b><small class="d-block suave">Aviso: ${esc(fecha(s.fechaAviso))}</small></div>` },
      { titulo: 'Póliza / cliente', celda: (s) => `<div><span class="mono">${esc(s.poliza)}</span><small class="d-block suave">${esc(s.cliente)}</small></div>` },
      { titulo: 'Descripción', celda: (s) => `<span style="display:block;max-width:340px">${esc(s.descripcion)}</span>` },
      { titulo: 'Valor reclamado', clase: 'der', celda: (s) => `<span class="monto">${esc(pesos(s.valorReclamado))}</span>` },
      { titulo: 'Estado', celda: (s) => { const e = ESTADOS[s.estado] || { nombre: s.estado, clase: 'neutro' }; return `<span class="semaforo ${e.clase}">${esc(e.nombre)}</span>`; } }
    ]
  });
}
