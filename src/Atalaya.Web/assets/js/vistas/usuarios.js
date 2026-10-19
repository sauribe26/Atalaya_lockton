/* =====================================================================
   vistas/usuarios.js — Gestión de usuarios (menú USUARIOS).
   · Lista con búsqueda en el servidor (GET /api/users?buscar=, con debounce).
   · Interruptor activar/inactivar (PATCH /api/users/{id}/estado).
   · Modal "Nuevo usuario" (POST /api/users) con validación en vivo según
     las reglas del contrato y medidor de fortaleza de la clave; pinta los
     errores 400 por campo (detalles) y los 409 de duplicados.
   · Botón "Menús" por fila → #/asignacion?usuario=ID.
   ===================================================================== */
import { api } from '../api.js';
import { esc, fechaHora, debounce, iniciales, aviso, procesando, esqueletoFilas, bloqueError, vacio } from '../ui.js';

/** Reglas de validación (las mismas que aplica el servidor). */
export const REGLAS = {
  usuario: /^[a-z0-9._-]+$/,
  correo: /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/,
  requisitosClave: [
    { id: 'largo', texto: 'Mínimo 8 caracteres', ok: (c) => c.length >= 8 },
    { id: 'mayus', texto: 'Una mayúscula', ok: (c) => /[A-ZÁÉÍÓÚÑ]/.test(c) },
    { id: 'minus', texto: 'Una minúscula', ok: (c) => /[a-záéíóúñ]/.test(c) },
    { id: 'numero', texto: 'Un número', ok: (c) => /\d/.test(c) },
    { id: 'simbolo', texto: 'Un símbolo (#, $, !…)', ok: (c) => /[^A-Za-z0-9\sÁÉÍÓÚÑáéíóúñ]/.test(c) }
  ]
};

/**
 * @param {HTMLElement} el
 * @param {{usuario:any, vigente:Function}} ctx
 */
export async function mostrar(el, ctx) {
  let usuarios = [];
  let consulta = 0;

  el.innerHTML = `
    <div class="encabezado">
      <div><div class="antetitulo">Gestión</div><h1>Usuarios</h1><p>Cree cuentas y active o inactive el ingreso de cada persona.</p></div>
      <div class="acciones"><button class="btn btn-primary" id="btn-nuevo" type="button"><i class="bi bi-person-plus" aria-hidden="true"></i> Nuevo usuario</button></div>
    </div>
    <div class="barra-filtros">
      <div class="buscador"><i class="bi bi-search" aria-hidden="true"></i>
        <input class="form-control" id="buscar" type="search" placeholder="Buscar por nombre, usuario o correo" aria-label="Buscar usuarios"></div>
      <span class="contador" id="contador" aria-live="polite"></span>
    </div>
    <div id="lista">${esqueletoFilas(5)}</div>`;

  const lista = el.querySelector('#lista');

  async function cargar() {
    const q = el.querySelector('#buscar').value.trim();
    const mio = ++consulta;
    try {
      const r = await api.get(`/api/users${q ? `?buscar=${encodeURIComponent(q)}` : ''}`);
      if (mio !== consulta || !ctx.vigente()) return;
      usuarios = Array.isArray(r) ? r : [];
      pintar();
    } catch (err) {
      if (mio === consulta && ctx.vigente()) lista.innerHTML = bloqueError(err);
    }
  }

  function pintar() {
    el.querySelector('#contador').textContent = `${usuarios.length} usuario(s)`;
    if (!usuarios.length) {
      lista.innerHTML = `<div class="tarjeta">${vacio('people', 'No hay usuarios que coincidan', 'Pruebe con otra búsqueda.')}</div>`;
      return;
    }
    const yo = ctx.usuario && ctx.usuario.id;
    lista.innerHTML = `
      <div class="tabla apilable"><div class="envoltura"><table>
        <thead><tr><th>Usuario</th><th>Correo</th><th>Estado</th><th class="der">Menús</th><th>Último acceso</th><th class="der">Acciones</th></tr></thead>
        <tbody>${usuarios.map((u) => `
          <tr data-id="${Number(u.id)}">
            <td><div class="persona"><span class="iniciales ${u.activo ? '' : 'off'}">${esc(iniciales(u.nombre))}</span>
              <div><b>${esc(u.nombre)}</b><small>@${esc(u.usuario)}${u.id === yo ? ' · <span class="etiqueta acento">Usted</span>' : ''}</small></div></div></td>
            <td data-etq="Correo">${esc(u.correo)}</td>
            <td data-etq="Estado">
              <div class="d-flex align-items-center gap-2">
                <div class="form-check form-switch m-0">
                  <input class="form-check-input sw-estado" type="checkbox" role="switch" ${u.activo ? 'checked' : ''} ${u.id === yo ? 'disabled title="No puede inactivarse a sí mismo"' : ''}
                    aria-label="Usuario ${esc(u.usuario)} activo">
                </div>
                <span class="semaforo ${u.activo ? 'ok' : 'neutro'}">${u.activo ? 'Activo' : 'Inactivo'}</span>
              </div></td>
            <td data-etq="Menús asignados" class="der"><span class="etiqueta acento">${Number(u.totalMenus) || 0}</span></td>
            <td data-etq="Último acceso"><span class="suave">${u.ultimoAcceso ? esc(fechaHora(u.ultimoAcceso)) : 'Nunca'}</span></td>
            <td class="acc"><a class="btn btn-sm btn-suave" href="#/asignacion?usuario=${Number(u.id)}"><i class="bi bi-diagram-3" aria-hidden="true"></i> Menús</a></td>
          </tr>`).join('')}
        </tbody></table></div></div>`;
  }

  // Activar / inactivar.
  lista.addEventListener('change', async (e) => {
    const sw = e.target.closest('.sw-estado');
    if (!sw) return;
    const id = Number(sw.closest('tr').dataset.id);
    const activo = sw.checked;
    sw.disabled = true;
    try {
      const actualizado = await api.patch(`/api/users/${id}/estado`, { activo });
      const i = usuarios.findIndex((u) => u.id === id);
      if (i >= 0) usuarios[i] = { ...usuarios[i], ...(actualizado || {}), activo };
      aviso(`Usuario ${activo ? 'activado' : 'inactivado'}.`, 'ok');
      pintar();
    } catch (err) {
      sw.checked = !activo;
      sw.disabled = false;
      aviso(err.mensaje || 'No fue posible cambiar el estado.', 'error');
    }
  });

  el.querySelector('#buscar').addEventListener('input', debounce(cargar, 350));
  el.querySelector('#btn-nuevo').addEventListener('click', () => abrirModalNuevo(cargar));
  await cargar();
}

/* ---------- Modal "Nuevo usuario" ---------- */

/** Crea (una sola vez por apertura) y muestra el modal de nuevo usuario. */
function abrirModalNuevo(alGuardar) {
  const div = document.createElement('div');
  div.className = 'modal fade';
  div.tabIndex = -1;
  div.setAttribute('aria-labelledby', 'titulo-nuevo');
  div.innerHTML = `
    <div class="modal-dialog modal-lg modal-dialog-centered">
      <form class="modal-content" novalidate>
        <div class="modal-header">
          <h2 class="modal-title" id="titulo-nuevo"><span class="sello-ico" style="width:36px;height:36px;font-size:16px"><i class="bi bi-person-plus" aria-hidden="true"></i></span> Nuevo usuario</h2>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div id="error-general"></div>
          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label" for="nu-nombre">Nombre completo</label>
              <input class="form-control" id="nu-nombre" name="nombre" maxlength="120" autocomplete="off" required>
              <div class="invalid-feedback"></div>
            </div>
            <div class="col-md-6">
              <label class="form-label" for="nu-usuario">Usuario</label>
              <input class="form-control mono" id="nu-usuario" name="usuario" maxlength="50" autocomplete="off" required aria-describedby="ayuda-usuario">
              <div class="form-text" id="ayuda-usuario">Minúsculas, números y . _ - (3 a 50).</div>
              <div class="invalid-feedback"></div>
            </div>
            <div class="col-12">
              <label class="form-label" for="nu-correo">Correo</label>
              <input class="form-control" id="nu-correo" name="correo" type="email" maxlength="150" autocomplete="off" required>
              <div class="invalid-feedback"></div>
            </div>
            <div class="col-md-6">
              <label class="form-label" for="nu-clave">Contraseña</label>
              <div class="campo-ico"><i class="bi bi-lock" aria-hidden="true"></i>
                <input class="form-control" id="nu-clave" name="clave" type="password" autocomplete="new-password" required aria-describedby="req-clave" style="padding-right:46px">
                <button type="button" class="btn-ico ver-clave" aria-label="Mostrar contraseña"><i class="bi bi-eye" aria-hidden="true"></i></button>
              </div>
              <div class="medidor" data-nivel="0" aria-hidden="true"><i></i><i></i><i></i><i></i></div>
              <ul class="requisitos" id="req-clave">${REGLAS.requisitosClave.map((r) => `<li data-req="${r.id}"><i class="bi bi-circle" aria-hidden="true"></i>${r.texto}</li>`).join('')}</ul>
              <div class="invalid-feedback d-block" data-error="clave"></div>
            </div>
            <div class="col-md-6">
              <label class="form-label" for="nu-confirmar">Confirmar contraseña</label>
              <input class="form-control" id="nu-confirmar" type="password" autocomplete="new-password" required>
              <div class="invalid-feedback"></div>
              <div class="form-check form-switch mt-4">
                <input class="form-check-input" type="checkbox" role="switch" id="nu-activo" checked>
                <label class="form-check-label fw-semibold" for="nu-activo">Usuario activo (puede ingresar)</label>
              </div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn btn-primary" id="nu-guardar"><i class="bi bi-check2" aria-hidden="true"></i> Crear usuario</button>
        </div>
      </form>
    </div>`;
  document.body.appendChild(div);
  const modal = new window.bootstrap.Modal(div);
  const f = div.querySelector('form');
  const campo = (n) => f.querySelector(`#nu-${n}`);
  const tocados = new Set();

  function marcar(nombre, mensaje) {
    const input = campo(nombre);
    input.classList.toggle('is-invalid', !!mensaje);
    input.classList.toggle('is-valid', !mensaje && tocados.has(nombre));
    const fb = nombre === 'clave' ? f.querySelector('[data-error="clave"]') : input.closest('div[class^="col"]').querySelector('.invalid-feedback');
    if (fb) fb.textContent = mensaje || '';
  }

  /** Valida un campo y devuelve el mensaje de error ('' si está bien). */
  function validar(nombre) {
    const v = campo(nombre).value;
    switch (nombre) {
      case 'nombre': { const t = v.trim().length; return t < 3 || t > 120 ? 'El nombre debe tener entre 3 y 120 caracteres.' : ''; }
      case 'usuario':
        if (v.length < 3 || v.length > 50) return 'El usuario debe tener entre 3 y 50 caracteres.';
        return REGLAS.usuario.test(v) ? '' : 'Solo minúsculas, números, punto, guion y guion bajo.';
      case 'correo': return REGLAS.correo.test(v.trim()) ? '' : 'Escriba un correo válido.';
      case 'clave': return REGLAS.requisitosClave.every((r) => r.ok(v)) ? '' : 'La contraseña no cumple todos los requisitos.';
      case 'confirmar': return v && v === campo('clave').value ? '' : 'Las contraseñas no coinciden.';
      default: return '';
    }
  }

  function medidor() {
    const c = campo('clave').value;
    let cumple = 0;
    REGLAS.requisitosClave.forEach((r) => {
      const ok = r.ok(c);
      if (ok) cumple++;
      const li = f.querySelector(`[data-req="${r.id}"]`);
      li.classList.toggle('cumple', ok);
      li.querySelector('.bi').className = `bi bi-${ok ? 'check-circle-fill' : 'circle'}`;
    });
    f.querySelector('.medidor').dataset.nivel = c ? String(Math.max(1, Math.round((cumple / 5) * 4))) : '0';
  }

  ['nombre', 'usuario', 'correo', 'clave', 'confirmar'].forEach((n) => {
    campo(n).addEventListener('input', () => {
      if (n === 'usuario') {
        const pos = campo(n).selectionStart;
        campo(n).value = campo(n).value.toLowerCase().replace(/\s/g, '');
        try { campo(n).setSelectionRange(pos, pos); } catch { /* sin selección */ }
      }
      if (n === 'clave') { medidor(); if (tocados.has('confirmar')) marcar('confirmar', validar('confirmar')); }
      if (tocados.has(n)) marcar(n, validar(n));
    });
    campo(n).addEventListener('blur', () => { if (campo(n).value) { tocados.add(n); marcar(n, validar(n)); } });
  });

  f.querySelector('.ver-clave').addEventListener('click', (e) => {
    const ver = campo('clave').type === 'password';
    campo('clave').type = ver ? 'text' : 'password';
    campo('confirmar').type = ver ? 'text' : 'password';
    e.currentTarget.innerHTML = `<i class="bi bi-${ver ? 'eye-slash' : 'eye'}" aria-hidden="true"></i>`;
    e.currentTarget.setAttribute('aria-label', ver ? 'Ocultar contraseña' : 'Mostrar contraseña');
  });

  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    f.querySelector('#error-general').innerHTML = '';
    let primero = null;
    ['nombre', 'usuario', 'correo', 'clave', 'confirmar'].forEach((n) => {
      tocados.add(n);
      const m = validar(n);
      marcar(n, m);
      if (m && !primero) primero = campo(n);
    });
    if (primero) { primero.focus(); return; }

    const boton = f.querySelector('#nu-guardar');
    boton.disabled = true;
    procesando(true, 'Creando usuario…');
    try {
      const nuevo = await api.post('/api/users', {
        nombre: campo('nombre').value.trim(),
        usuario: campo('usuario').value.trim(),
        correo: campo('correo').value.trim(),
        clave: campo('clave').value,
        activo: campo('activo').checked
      });
      modal.hide();
      aviso(`Usuario ${nuevo && nuevo.usuario ? '@' + nuevo.usuario : ''} creado. Ahora puede asignarle menús.`, 'ok');
      alGuardar();
    } catch (err) {
      boton.disabled = false;
      if (err.estado === 400 && err.detalles) {
        Object.entries(err.detalles).forEach(([clave, msg]) => {
          const n = clave.charAt(0).toLowerCase() + clave.slice(1);
          if (campo(n)) marcar(n, msg); else f.querySelector('#error-general').innerHTML += bloqueError({ mensaje: msg });
        });
      } else if (err.codigo === 'USUARIO_DUPLICADO') {
        marcar('usuario', 'Ese usuario ya existe.'); campo('usuario').focus();
      } else if (err.codigo === 'CORREO_DUPLICADO') {
        marcar('correo', 'Ese correo ya está registrado.'); campo('correo').focus();
      } else {
        f.querySelector('#error-general').innerHTML = bloqueError(err);
      }
    } finally {
      procesando(false);
    }
  });

  div.addEventListener('shown.bs.modal', () => campo('nombre').focus());
  div.addEventListener('hidden.bs.modal', () => { modal.dispose(); div.remove(); });
  modal.show();
}
