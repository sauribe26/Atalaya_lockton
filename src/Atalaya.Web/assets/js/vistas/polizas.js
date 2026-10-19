/* =====================================================================
   vistas/polizas.js — Pólizas (menú POLIZAS).
   Listado de GET /api/polizas con búsqueda local, chips por estado,
   primas en pesos con punto de miles fijo y barra de vigencia con aviso
   según "diasParaVencer" (vencida / por vencer ≤ 30 días / al día).
   ===================================================================== */
import { esc, fecha, pesos, miles, partesFecha } from '../ui.js';
import { listado, resumenKpis } from '../tabla.js';

const ESTADOS = {
  VIGENTE: { nombre: 'Vigente', clase: 'ok' },
  POR_RENOVAR: { nombre: 'Por renovar', clase: 'alerta' },
  VENCIDA: { nombre: 'Vencida', clase: 'error' }
};

/** Días (enteros) de una fecha ISO, sin zona horaria. */
function dias(iso) {
  const p = partesFecha(iso);
  return p ? Date.UTC(p.a, p.m - 1, p.d) / 86400000 : null;
}

/** HTML de la barra de vigencia: avance del periodo y aviso de vencimiento. */
function vigencia(p) {
  const d = Number(p.diasParaVencer) || 0;
  const ini = dias(p.vigenciaDesde);
  const fin = dias(p.vigenciaHasta);
  const total = ini !== null && fin !== null ? Math.max(1, fin - ini) : 365;
  const avance = Math.max(0, Math.min(100, ((total - Math.max(0, d)) / total) * 100));
  let color = '#15803d';
  let texto = `Vence en ${miles(d)} días`;
  if (d < 0) { color = '#b91c1c'; texto = `Venció hace ${miles(-d)} días`; }
  else if (d === 0) { color = '#b91c1c'; texto = 'Vence hoy'; }
  else if (d <= 30) { color = '#b45309'; }
  const icono = d <= 30 ? `<i class="bi bi-${d < 0 ? 'x-octagon' : 'exclamation-triangle'}" style="color:${color}" aria-hidden="true"></i> ` : '';
  return `<div class="vencimiento"><small>${icono}${esc(texto)}</small>
    <div class="pista" role="progressbar" aria-label="Vigencia transcurrida" aria-valuenow="${Math.round(avance)}" aria-valuemin="0" aria-valuemax="100"><i style="width:${avance.toFixed(1)}%;background:${color}"></i></div>
    <small class="suave fw-normal">${esc(fecha(p.vigenciaDesde))} → ${esc(fecha(p.vigenciaHasta))}</small></div>`;
}

/**
 * @param {HTMLElement} el
 * @param {{vigente:Function}} ctx
 */
export async function mostrar(el, ctx) {
  await listado(el, ctx, {
    antetitulo: 'Operación', titulo: 'Pólizas', icono: 'file-earmark-text',
    descripcion: 'Pólizas colocadas por el corredor, con su vigencia y prima.',
    endpoint: '/api/polizas', placeholder: 'Buscar por número, cliente, ramo o aseguradora',
    texto: (p) => `${p.numero} ${p.cliente} ${p.ramo} ${p.aseguradora}`,
    estados: Object.entries(ESTADOS).map(([valor, v]) => ({ valor, nombre: v.nombre })),
    campoEstado: 'estado',
    orden: (a, b) => (Number(a.diasParaVencer) || 0) - (Number(b.diasParaVencer) || 0),
    resumen: (f) => resumenKpis([
      { nombre: 'Pólizas', valor: miles(f.length), icono: 'file-earmark-text', tono: 'tinta' },
      { nombre: 'Primas totales', valor: pesos(f.reduce((s, p) => s + (Number(p.prima) || 0), 0)), icono: 'cash-stack', tono: 'verde' },
      { nombre: 'Vencen en ≤ 30 días', valor: miles(f.filter((p) => Number(p.diasParaVencer) >= 0 && Number(p.diasParaVencer) <= 30).length), icono: 'hourglass-split', tono: 'ambar' },
      { nombre: 'Vencidas', valor: miles(f.filter((p) => Number(p.diasParaVencer) < 0 || p.estado === 'VENCIDA').length), icono: 'x-octagon', tono: 'rojo' }
    ]),
    columnas: [
      { titulo: 'Póliza', celda: (p) => `<div><b class="tinta mono">${esc(p.numero)}</b><small class="d-block suave">${esc(p.cliente)}</small></div>` },
      { titulo: 'Ramo', celda: (p) => `<span class="etiqueta acento">${esc(p.ramo)}</span>` },
      { titulo: 'Aseguradora', celda: (p) => esc(p.aseguradora) },
      { titulo: 'Prima', clase: 'der', celda: (p) => `<span class="monto">${esc(pesos(p.prima))}</span>` },
      { titulo: 'Vigencia', celda: vigencia },
      { titulo: 'Estado', celda: (p) => { const s = ESTADOS[p.estado] || { nombre: p.estado, clase: 'neutro' }; return `<span class="semaforo ${s.clase}">${esc(s.nombre)}</span>`; } }
    ]
  });
}
