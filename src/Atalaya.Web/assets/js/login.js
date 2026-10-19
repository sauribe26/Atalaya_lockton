/* =====================================================================
   login.js — Lógica de la pantalla de ingreso.
   · Envía POST /api/auth/login { login, clave }.
   · Interpreta el código de error: CREDENCIALES_INVALIDAS (401),
     USUARIO_INACTIVO (403), USUARIO_BLOQUEADO (423, con minutos) y 400.
   · Guarda token y usuario en sessionStorage y abre index.html#/inicio.
   · Panel "Usuarios de prueba" que llena el formulario (sustentación).
   ===================================================================== */
import { api, ErrorApi } from './api.js';
import { guardarSesion, haySesion } from './sesion.js';
import { esc } from './ui.js';

/** Usuarios semilla del contrato (credenciales de PRUEBA, no reales). */
const USUARIOS_DEMO = [
  { usuario: 'admin', clave: 'Admin#2026', icono: 'person-gear', nota: 'Los 7 menús' },
  { usuario: 'analista', clave: 'Analista#2026', icono: 'graph-up', nota: 'Tablero, Pólizas, Siniestros' },
  { usuario: 'consulta', clave: 'Consulta#2026', icono: 'search', nota: 'Clientes, Pólizas' },
  { usuario: 'auditor', clave: 'Auditor#2026', icono: 'person-slash', nota: 'INACTIVO (prueba de rechazo)' }
];

const form = document.getElementById('form-login');
const campoLogin = document.getElementById('login');
const campoClave = document.getElementById('clave');
const zonaMensaje = document.getElementById('mensaje');
const boton = document.getElementById('btn-entrar');

// Si ya hay sesión vigente, entrar directo.
if (haySesion()) window.location.replace('index.html#/inicio');

// Aviso por el motivo de llegada (sesión expirada / salida voluntaria).
const motivo = new URLSearchParams(window.location.search).get('motivo');
if (motivo === 'expirada') {
  document.getElementById('aviso-motivo').innerHTML = '<div class="aviso alerta"><i class="bi bi-clock-history" aria-hidden="true"></i><div>Su sesión expiró o no es válida. Ingrese de nuevo.</div></div>';
} else if (motivo === 'salir') {
  document.getElementById('aviso-motivo').innerHTML = '<div class="aviso ok"><i class="bi bi-check-circle" aria-hidden="true"></i><div>Sesión cerrada correctamente.</div></div>';
}

/** Pinta un mensaje en el formulario. */
function mostrar(tipo, icono, html) {
  zonaMensaje.innerHTML = `<div class="aviso ${tipo}"><i class="bi bi-${icono}" aria-hidden="true"></i><div>${html}</div></div>`;
}

/** Activa/desactiva el estado "cargando" del botón. */
function cargando(si) {
  boton.disabled = si;
  boton.querySelector('.spinner-border').classList.toggle('d-none', !si);
  boton.querySelector('.texto').textContent = si ? 'Validando…' : 'Ingresar';
}

// Mostrar / ocultar contraseña.
document.getElementById('ver-clave').addEventListener('click', (e) => {
  const b = e.currentTarget;
  const ver = campoClave.type === 'password';
  campoClave.type = ver ? 'text' : 'password';
  b.setAttribute('aria-pressed', String(ver));
  b.setAttribute('aria-label', ver ? 'Ocultar contraseña' : 'Mostrar contraseña');
  b.innerHTML = `<i class="bi bi-${ver ? 'eye-slash' : 'eye'}" aria-hidden="true"></i>`;
  campoClave.focus();
});

// Quitar marcas de error al escribir.
[campoLogin, campoClave].forEach((c) => c.addEventListener('input', () => c.classList.remove('is-invalid')));

// Envío del formulario.
form.addEventListener('submit', async (e) => {
  e.preventDefault();
  zonaMensaje.innerHTML = '';
  const login = campoLogin.value.trim();
  const clave = campoClave.value;
  if (!login || !clave) {
    if (!login) campoLogin.classList.add('is-invalid');
    if (!clave) campoClave.classList.add('is-invalid');
    mostrar('error', 'exclamation-circle', 'Ingrese su usuario (o correo) y su contraseña.');
    (login ? campoClave : campoLogin).focus();
    return;
  }

  cargando(true);
  try {
    const r = await api.post('/api/auth/login', { login, clave }, { anonimo: true });
    guardarSesion(r.token, r.usuario, r.expiraEn);
    mostrar('ok', 'check-circle', `Hola, ${esc(r.usuario && r.usuario.nombre)}. Preparando su espacio…`);
    window.location.replace('index.html#/inicio');
  } catch (err) {
    cargando(false);
    const e2 = err instanceof ErrorApi ? err : new ErrorApi(0, 'DESCONOCIDO', 'Error inesperado.');
    switch (e2.codigo) {
      case 'CREDENCIALES_INVALIDAS':
        mostrar('error', 'x-circle', 'Usuario o contraseña incorrectos. Tras 5 intentos fallidos seguidos la cuenta se bloquea 15 minutos.');
        campoClave.value = '';
        campoClave.classList.add('is-invalid');
        campoClave.focus();
        break;
      case 'USUARIO_INACTIVO':
        mostrar('alerta', 'person-slash', 'Su usuario está <b>inactivo</b>. Solicite al administrador que lo active.');
        break;
      case 'USUARIO_BLOQUEADO':
        mostrar('error', 'lock', `<b>Cuenta bloqueada temporalmente.</b> ${esc(e2.mensaje)}`);
        break;
      default:
        if (e2.estado === 400 && e2.detalles) {
          const lista = Object.values(e2.detalles).map((m) => `<li>${esc(m)}</li>`).join('');
          mostrar('error', 'exclamation-circle', `Revise los datos:<ul class="mb-0 ps-3">${lista}</ul>`);
        } else {
          mostrar('error', 'wifi-off', esc(e2.mensaje));
        }
    }
  }
});

// Panel de usuarios de prueba.
document.getElementById('usuarios-demo').innerHTML = USUARIOS_DEMO.map((u, i) => `
  <button type="button" class="usuario-demo" data-i="${i}">
    <b><i class="bi bi-${u.icono}" aria-hidden="true"></i>${esc(u.usuario)}</b>
    <small class="mono">${esc(u.clave)}</small>
    <small>${esc(u.nota)}</small>
  </button>`).join('');
document.getElementById('usuarios-demo').addEventListener('click', (e) => {
  const b = e.target.closest('.usuario-demo');
  if (!b) return;
  const u = USUARIOS_DEMO[Number(b.dataset.i)];
  campoLogin.value = u.usuario;
  campoClave.value = u.clave;
  zonaMensaje.innerHTML = '';
  boton.focus();
});
