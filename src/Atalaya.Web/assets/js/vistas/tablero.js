/* =====================================================================
   vistas/tablero.js — Tablero de control (GET /api/tablero).
   · 8 KPIs con animación de conteo.
   · Serie de 14 días (logins OK, fallidos, accesos denegados) en líneas/áreas.
   · Uso por menú (cuántos usuarios tienen cada menú) en barras horizontales.
   · Matriz de acceso usuarios × menús: visión de un vistazo de quién ve qué.
   Gráficos con Chart.js 4.4.1 (global window.Chart cargado en index.html).
   Paleta de series validada para daltonismo (ver comentario en COLORES).
   ===================================================================== */
import { api } from '../api.js';
import { esc, miles, fechaCorta, animarConteo, esqueletoBloques, bloqueError, iniciales, vacio } from '../ui.js';

/** Colores de serie (validados: luminancia, croma, separación CVD y contraste ≥ 3:1). */
const COLORES = { ok: '#0086a8', fallido: '#c27a1a', denegado: '#be3455' };

const KPIS = [
  { clave: 'usuariosTotal',     nombre: 'Usuarios',             icono: 'people',             tono: 'tinta', nota: 'registrados' },
  { clave: 'usuariosActivos',   nombre: 'Usuarios activos',     icono: 'person-check',       tono: 'verde', nota: 'pueden ingresar' },
  { clave: 'menusActivos',      nombre: 'Menús activos',        icono: 'grid-3x3-gap',       tono: '',      nota: 'en el catálogo' },
  { clave: 'asignacionesTotal', nombre: 'Asignaciones',         icono: 'diagram-3',          tono: '',      nota: 'usuario × menú' },
  { clave: 'loginsHoy',         nombre: 'Ingresos hoy',         icono: 'box-arrow-in-right', tono: 'verde', nota: 'exitosos' },
  { clave: 'fallidos7d',        nombre: 'Intentos fallidos',    icono: 'x-circle',           tono: 'ambar', nota: 'últimos 7 días' },
  { clave: 'denegados7d',       nombre: 'Accesos denegados',    icono: 'shield-x',           tono: 'rojo',  nota: 'últimos 7 días (403)' },
  { clave: 'bloqueadosAhora',   nombre: 'Bloqueados ahora',     icono: 'lock',               tono: 'rojo',  nota: 'por 5 intentos' }
];

/**
 * @param {HTMLElement} el
 * @param {{vigente:Function}} ctx
 * @returns {Promise<Function>} limpieza (destruye los gráficos)
 */
export async function mostrar(el, ctx) {
  const graficos = [];
  el.innerHTML = `
    <div class="encabezado">
      <div><div class="antetitulo">Control</div><h1>Tablero</h1><p>Cómo se está usando Atalaya y quién tiene acceso a qué.</p></div>
      <div class="acciones"><button class="btn btn-light" id="btn-recargar" type="button"><i class="bi bi-arrow-clockwise" aria-hidden="true"></i> Actualizar</button></div>
    </div>
    <div id="cuerpo">${esqueletoBloques(8)}<div class="rejilla-tablero"><div class="esqueleto" style="height:340px;border-radius:14px"></div><div class="esqueleto" style="height:340px;border-radius:14px"></div></div></div>`;

  const cuerpo = el.querySelector('#cuerpo');

  async function cargar() {
    graficos.splice(0).forEach((g) => g.destroy());
    let datos;
    try {
      datos = await api.get('/api/tablero');
    } catch (err) {
      if (ctx.vigente()) cuerpo.innerHTML = bloqueError(err);
      return;
    }
    if (!ctx.vigente()) return;
    pintar(cuerpo, datos, graficos);
  }

  el.querySelector('#btn-recargar').addEventListener('click', cargar);
  await cargar();
  return () => graficos.forEach((g) => g.destroy());
}

/** Pinta KPIs, gráficos y matriz. */
function pintar(cuerpo, datos, graficos) {
  const kpis = datos.kpis || {};
  const serie = datos.serie || [];
  const uso = datos.usoMenus || [];
  const matriz = datos.matriz || [];

  cuerpo.innerHTML = `
    <div class="kpis">
      ${KPIS.map((k, i) => `
        <div class="kpi ${k.tono}" style="animation-delay:${i * 40}ms">
          <span class="sello-ico"><i class="bi bi-${k.icono}" aria-hidden="true"></i></span>
          <div class="datos"><span>${esc(k.nombre)}</span><b data-valor="${Number(kpis[k.clave]) || 0}">0</b><small>${esc(k.nota)}</small></div>
        </div>`).join('')}
    </div>

    <div class="rejilla-tablero">
      <section class="tarjeta">
        <div class="tarjeta-cabeza"><h3>Actividad de los últimos 14 días</h3><small>Ingresos y rechazos por día</small></div>
        <div class="graf"><canvas id="graf-serie" role="img" aria-label="Gráfico de ingresos exitosos, intentos fallidos y accesos denegados por día"></canvas></div>
      </section>
      <section class="tarjeta">
        <div class="tarjeta-cabeza"><h3>Uso por menú</h3><small>Usuarios con el menú asignado</small></div>
        <div class="graf"><canvas id="graf-uso" role="img" aria-label="Número de usuarios por menú"></canvas></div>
      </section>
      <section class="tarjeta ancho-completo">
        <div class="tarjeta-cabeza">
          <h3><i class="bi bi-grid-3x3" aria-hidden="true"></i> Matriz de acceso</h3>
          <div class="leyenda"><span><i class="punto si"></i> Tiene el menú</span><span><i class="punto"></i> No lo tiene</span></div>
        </div>
        <div id="matriz"></div>
      </section>
    </div>`;

  cuerpo.querySelectorAll('.kpi b[data-valor]').forEach((b) => animarConteo(b, Number(b.dataset.valor)));
  pintarMatriz(cuerpo.querySelector('#matriz'), uso, matriz);

  const Chart = window.Chart;
  if (!Chart) return;
  Chart.defaults.font.family = "'Plus Jakarta Sans', system-ui, sans-serif";
  Chart.defaults.color = '#4b5563';

  const tooltip = {
    backgroundColor: '#ffffff', titleColor: '#0f3d56', bodyColor: '#4b5563', borderColor: '#e6eaef', borderWidth: 1,
    padding: 10, boxPadding: 4, usePointStyle: true, cornerRadius: 8
  };

  // Serie de 14 días (líneas con área suave; 2px; puntos visibles al pasar).
  if (serie.length) {
    const linea = (etq, clave, color, relleno) => ({
      label: etq, data: serie.map((s) => Number(s[clave]) || 0), borderColor: color, backgroundColor: relleno ? `${color}1f` : color,
      fill: relleno, tension: .35, borderWidth: 2, pointRadius: 0, pointHoverRadius: 5, pointHoverBorderWidth: 2, pointHoverBorderColor: '#fff', pointBackgroundColor: color
    });
    graficos.push(new Chart(cuerpo.querySelector('#graf-serie'), {
      type: 'line',
      data: {
        labels: serie.map((s) => fechaCorta(s.dia)),
        datasets: [
          linea('Ingresos exitosos', 'loginsOk', COLORES.ok, true),
          linea('Intentos fallidos', 'loginsFallidos', COLORES.fallido, false),
          linea('Accesos denegados', 'accesosDenegados', COLORES.denegado, false)
        ]
      },
      options: {
        maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { position: 'bottom', labels: { usePointStyle: true, pointStyle: 'circle', boxWidth: 8, padding: 16 } },
          tooltip: { ...tooltip, callbacks: { label: (c) => ` ${c.dataset.label}: ${miles(c.parsed.y)}` } }
        },
        scales: {
          x: { grid: { display: false }, ticks: { maxRotation: 0, autoSkipPadding: 12 } },
          y: { beginAtZero: true, ticks: { precision: 0, callback: (v) => miles(v) }, grid: { color: '#eef1f4' }, border: { display: false } }
        }
      }
    }));
  } else {
    cuerpo.querySelector('#graf-serie').parentElement.innerHTML = vacio('graph-up', 'Sin actividad registrada');
  }

  // Uso por menú: magnitud de una sola variable → barras horizontales en un solo tono.
  if (uso.length) {
    graficos.push(new Chart(cuerpo.querySelector('#graf-uso'), {
      type: 'bar',
      data: {
        labels: uso.map((u) => u.nombre),
        datasets: [{ label: 'Usuarios', data: uso.map((u) => Number(u.totalUsuarios) || 0), backgroundColor: COLORES.ok, hoverBackgroundColor: '#17657b', borderRadius: 4, borderSkipped: 'start', barThickness: 18 }]
      },
      options: {
        indexAxis: 'y', maintainAspectRatio: false,
        plugins: { legend: { display: false }, tooltip: { ...tooltip, callbacks: { label: (c) => ` ${miles(c.parsed.x)} usuario(s)` } } },
        scales: {
          x: { beginAtZero: true, ticks: { precision: 0 }, grid: { color: '#eef1f4' }, border: { display: false } },
          y: { grid: { display: false }, border: { display: false } }
        }
      }
    }));
  } else {
    cuerpo.querySelector('#graf-uso').parentElement.innerHTML = vacio('grid', 'Sin menús activos');
  }
}

/** Matriz usuarios × menús a partir de las filas {idUsuario, usuario, codigo}. */
function pintarMatriz(destino, uso, filas) {
  const menus = uso.map((u) => ({ codigo: u.codigo, nombre: u.nombre }));
  const usuarios = new Map();
  filas.forEach((f) => {
    if (!usuarios.has(f.idUsuario)) usuarios.set(f.idUsuario, { usuario: f.usuario, codigos: new Set() });
    usuarios.get(f.idUsuario).codigos.add(f.codigo);
  });
  if (!usuarios.size || !menus.length) {
    destino.innerHTML = vacio('grid-3x3', 'Aún no hay asignaciones', 'Asigne menús desde "Asignación de menús".');
    return;
  }
  const lista = [...usuarios.values()].sort((a, b) => String(a.usuario).localeCompare(String(b.usuario)));
  destino.innerHTML = `
    <div class="matriz-envoltura">
      <table class="matriz">
        <caption class="visually-hidden">Matriz de acceso: usuarios en filas y menús en columnas</caption>
        <thead><tr><th scope="col">Usuario</th>${menus.map((m) => `<th scope="col" title="${esc(m.nombre)}">${esc(m.nombre)}</th>`).join('')}<th scope="col">Total</th></tr></thead>
        <tbody>
          ${lista.map((u) => `<tr>
            <th scope="row" style="background:#fff;text-transform:none;letter-spacing:0;font-size:14px"><span class="usuario-celda"><span class="iniciales">${esc(iniciales(u.usuario))}</span>${esc(u.usuario)}</span></th>
            ${menus.map((m) => { const si = u.codigos.has(m.codigo); return `<td title="${esc(u.usuario)} · ${esc(m.nombre)}: ${si ? 'sí' : 'no'}"><span class="punto ${si ? 'si' : ''}" role="img" aria-label="${si ? 'Tiene acceso' : 'Sin acceso'}"></span></td>`; }).join('')}
            <td class="total">${u.codigos.size}</td></tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}
