/* =====================================================================
   vistas/manual.js — Manual de usuario dentro del aplicativo.
   Documento completo en español con índice lateral fijo y "scrollspy"
   (IntersectionObserver). Los enlaces del índice no usan el hash (lo usa
   el enrutador): desplazan la página con scrollIntoView.
   Contenido estático (no pinta datos del API).
   ===================================================================== */

/** Secciones del manual: id, título, ícono y cuerpo HTML. */
const SECCIONES = [
  {
    id: 'introduccion', titulo: 'Introducción', icono: 'compass',
    html: `
      <p><b>Atalaya</b> es un portal de <b>control de acceso por menús</b>. Cada persona ingresa con su usuario y ve únicamente los módulos (menús) que el administrador le asignó.</p>
      <p>La idea central es sencilla: <b>la interfaz oculta lo que no le corresponde, pero quien decide es el servidor</b>. Cada vez que se abre un módulo, el servidor vuelve a verificar en la base de datos que el usuario esté activo y tenga ese menú asignado. Si no lo tiene, responde <code>403</code> y deja constancia en la bitácora.</p>
      <div class="doc-nota"><i class="bi bi-lightbulb" aria-hidden="true"></i><div>Los clientes, pólizas y siniestros que aparecen son <b>datos ficticios de demostración</b> de un corredor de seguros.</div></div>`
  },
  {
    id: 'ingresar', titulo: 'Cómo ingresar', icono: 'box-arrow-in-right',
    html: `
      <ol class="doc-pasos">
        <li>Abra la página de ingreso (<code>login.html</code>).</li>
        <li>Escriba su <b>usuario</b> o su <b>correo</b>, y su <b>contraseña</b>. Con el ícono del ojo puede ver lo que escribió.</li>
        <li>Pulse <b>Ingresar</b>. Si los datos son correctos, entrará a la página de <b>Inicio</b>.</li>
      </ol>
      <h3>Mensajes que puede ver</h3>
      <div class="doc-tabla"><table>
        <thead><tr><th>Mensaje</th><th>Qué significa</th><th>Qué hacer</th></tr></thead>
        <tbody>
          <tr><td>Usuario o contraseña incorrectos</td><td>Los datos no coinciden (el sistema no dice cuál de los dos, por seguridad).</td><td>Revise mayúsculas y vuelva a intentar.</td></tr>
          <tr><td>Usuario inactivo</td><td>El administrador desactivó su cuenta.</td><td>Solicite que la activen.</td></tr>
          <tr><td>Cuenta bloqueada</td><td>Hubo 5 intentos fallidos seguidos. Se bloquea 15 minutos.</td><td>Espere los minutos indicados.</td></tr>
          <tr><td>Su sesión expiró</td><td>El token dura 8 horas, o fue rechazado.</td><td>Ingrese de nuevo.</td></tr>
        </tbody></table></div>
      <p>La sesión vive en la pestaña del navegador: al cerrarla, deberá ingresar otra vez. Para salir use el avatar (círculo con sus iniciales) → <b>Cerrar sesión</b>.</p>`
  },
  {
    id: 'menu', titulo: 'El menú dinámico', icono: 'layout-sidebar',
    html: `
      <p>La <b>barra lateral</b> se construye con los menús que el servidor le devuelve al ingresar (<code>GET /api/auth/yo</code>), agrupados en <b>Control</b>, <b>Gestión</b> y <b>Operación</b>. Además siempre verá <b>Inicio</b> y <b>Manual de uso</b>.</p>
      <ul class="doc-lista">
        <li><b>Contraer la barra:</b> use la pestaña azul del borde o el botón <i class="bi bi-list"></i>. Quedará un riel solo con íconos (se recuerda para la próxima vez).</li>
        <li><b>En el celular:</b> el botón <i class="bi bi-list"></i> abre el menú como un cajón sobre la pantalla.</li>
        <li><b>Buscar:</b> pulse <code>Ctrl + K</code> (o el cuadro "Buscar menú…") y escriba. Use las flechas y <code>Enter</code>. Solo aparecen sus menús.</li>
        <li><b>Barra superior:</b> muestra el módulo actual y la ruta (migas). El botón <i class="bi bi-question-circle"></i> abre este manual.</li>
      </ul>`
  },
  {
    id: 'inicio', titulo: 'Inicio', icono: 'house-door',
    html: `
      <p>Le saluda según la hora del día, resume <b>su acceso</b> (cuántos menús tiene y de cuántos grupos) y muestra tarjetas de acceso rápido <b>solo</b> a sus menús.</p>`
  },
  {
    id: 'tablero', titulo: 'Tablero', icono: 'speedometer2',
    html: `
      <p>Requiere el menú <code>TABLERO</code>. Presenta:</p>
      <ul class="doc-lista">
        <li><b>8 indicadores:</b> usuarios, activos, menús activos, asignaciones, ingresos de hoy, intentos fallidos y accesos denegados de los últimos 7 días, y usuarios bloqueados en este momento.</li>
        <li><b>Actividad de 14 días:</b> ingresos exitosos, fallidos y denegados por día. Pase el cursor para ver los valores.</li>
        <li><b>Uso por menú:</b> cuántos usuarios tienen cada menú.</li>
        <li><b>Matriz de acceso:</b> usuarios en filas, menús en columnas; un punto azul indica que la persona tiene ese menú. Es la forma más rápida de auditar "quién ve qué".</li>
      </ul>`
  },
  {
    id: 'usuarios', titulo: 'Usuarios', icono: 'people',
    html: `
      <p>Requiere el menú <code>USUARIOS</code>.</p>
      <h3>Buscar y cambiar el estado</h3>
      <ol class="doc-pasos">
        <li>Escriba en el buscador (nombre, usuario o correo); la lista se filtra en el servidor mientras escribe.</li>
        <li>Use el interruptor de la columna <b>Estado</b> para activar o inactivar. Un usuario inactivo no puede ingresar ni usar el API aunque tenga menús.</li>
        <li>No puede inactivarse a sí mismo (el servidor también lo impide).</li>
      </ol>
      <h3>Crear un usuario</h3>
      <ol class="doc-pasos">
        <li>Pulse <b>Nuevo usuario</b>.</li>
        <li>Complete nombre (3 a 120 caracteres), usuario (3 a 50, solo minúsculas, números, punto, guion y guion bajo) y correo.</li>
        <li>Escriba una contraseña: el medidor y la lista de requisitos se marcan en vivo (mínimo 8 caracteres, una mayúscula, una minúscula, un número y un símbolo). Confírmela.</li>
        <li>Pulse <b>Crear usuario</b>. Si el usuario o el correo ya existen, se le indica en el campo.</li>
        <li>Luego use el botón <b>Menús</b> de la fila para asignarle accesos.</li>
      </ol>`
  },
  {
    id: 'asignacion', titulo: 'Asignación de menús', icono: 'diagram-3',
    html: `
      <p>Requiere el menú <code>ASIGNACION</code>.</p>
      <ol class="doc-pasos">
        <li>Elija un usuario en la lista de la izquierda (puede buscarlo).</li>
        <li>A la derecha aparecen todos los menús agrupados. Encienda o apague cada tarjeta. Puede usar <b>Marcar todo</b> / <b>Quitar todo</b> por grupo.</li>
        <li>Abajo verá los <b>cambios pendientes</b>: <span class="text-success fw-bold">+ agregados</span> y <span class="text-danger fw-bold">− retirados</span>.</li>
        <li>Pulse <b>Guardar cambios</b>. El cambio aplica de inmediato: si a alguien se le quita un menú, su próxima petición a ese módulo será rechazada aunque tenga la pantalla abierta.</li>
      </ol>
      <div class="doc-nota alerta"><i class="bi bi-exclamation-triangle" aria-hidden="true"></i><div>No puede quitarse a sí mismo <b>Asignación de menús</b>: quedaría sin forma de administrar accesos (el servidor responde <code>409 AUTOBLOQUEO</code>). Si edita sus propios menús, su barra lateral se actualiza al guardar.</div></div>`
  },
  {
    id: 'auditoria', titulo: 'Bitácora de accesos', icono: 'shield-check',
    html: `
      <p>Requiere el menú <code>AUDITORIA</code>. Muestra, del más reciente al más antiguo, los eventos registrados por el servidor:</p>
      <div class="doc-tabla"><table><thead><tr><th>Evento</th><th>Cuándo ocurre</th></tr></thead><tbody>
        <tr><td>LOGIN_OK</td><td>Ingreso exitoso.</td></tr>
        <tr><td>LOGIN_FALLIDO</td><td>Contraseña o usuario errados.</td></tr>
        <tr><td>LOGIN_BLOQUEADO</td><td>Intento de ingreso con la cuenta bloqueada.</td></tr>
        <tr><td>ACCESO_DENEGADO</td><td>Alguien llamó un módulo sin tener el menú (403).</td></tr>
        <tr><td>USUARIO_CREADO</td><td>Se creó un usuario.</td></tr>
        <tr><td>USUARIO_ESTADO</td><td>Se activó o inactivó un usuario.</td></tr>
        <tr><td>MENUS_ACTUALIZADOS</td><td>Se cambiaron los menús de un usuario.</td></tr>
      </tbody></table></div>
      <p>Filtre con los <b>chips</b> de colores y, si quiere seguirla en vivo, active <b>Actualizar cada 15 s</b>.</p>`
  },
  {
    id: 'operacion', titulo: 'Clientes, pólizas y siniestros', icono: 'briefcase',
    html: `
      <p>Requieren los menús <code>CLIENTES</code>, <code>POLIZAS</code> y <code>SINIESTROS</code> respectivamente. Son listados de consulta con:</p>
      <ul class="doc-lista">
        <li><b>Resumen</b> arriba (totales y valores en pesos con punto de miles, por ejemplo <code>$ 150.000</code>).</li>
        <li><b>Buscador</b> que ignora tildes y mayúsculas, y <b>chips</b> por estado.</li>
        <li>En <b>Pólizas</b>, la columna Vigencia muestra cuánto del periodo ha transcurrido y avisa en ámbar si vence en 30 días o menos, y en rojo si ya venció.</li>
      </ul>`
  },
  {
    id: 'roles', titulo: 'Usuarios de prueba', icono: 'person-badge',
    html: `
      <p>Credenciales de <b>prueba</b> (no reales) para recorrer el aplicativo. En la pantalla de ingreso, el panel "Usuarios de prueba" las llena con un clic.</p>
      <div class="doc-tabla"><table><thead><tr><th>Usuario</th><th>Contraseña</th><th>Estado</th><th>Menús</th></tr></thead><tbody>
        <tr><td>admin</td><td><code>Admin#2026</code></td><td>Activo</td><td>Los 7 menús</td></tr>
        <tr><td>analista</td><td><code>Analista#2026</code></td><td>Activo</td><td>Tablero, Pólizas, Siniestros</td></tr>
        <tr><td>consulta</td><td><code>Consulta#2026</code></td><td>Activo</td><td>Clientes, Pólizas</td></tr>
        <tr><td>auditor</td><td><code>Auditor#2026</code></td><td>Inactivo</td><td>Bitácora (no puede ingresar mientras esté inactivo)</td></tr>
      </tbody></table></div>`
  },
  {
    id: 'sin-acceso', titulo: 'Qué significa "Sin acceso"', icono: 'shield-x',
    html: `
      <p>Si escribe a mano la dirección de un módulo que no tiene (por ejemplo <code>#/usuarios</code> entrando como <b>consulta</b>), verá la pantalla <b>Sin acceso</b>.</p>
      <p>Esa pantalla no se limita a ocultar: <b>llama de verdad</b> al servicio del módulo con su token y le muestra lo que respondió el servidor — normalmente <code>HTTP 403</code> con <code>"codigo": "ACCESO_DENEGADO"</code>. Ese intento queda además registrado en la bitácora.</p>
      <div class="doc-nota"><i class="bi bi-shield-check" aria-hidden="true"></i><div>Es la prueba visible de que la seguridad está en el servidor: aunque alguien manipulara la página o llamara el API con otra herramienta, sin el menú asignado la respuesta sería la misma.</div></div>`
  },
  {
    id: 'seguridad', titulo: 'Seguridad', icono: 'lock',
    html: `
      <ul class="doc-lista">
        <li><b>Contraseñas:</b> nunca se guardan en texto. Se almacena un <b>hash PBKDF2-SHA256</b> con <b>sal aleatoria</b> de 16 bytes por usuario y 100.000 iteraciones; la comparación se hace en tiempo constante.</li>
        <li><b>Token:</b> al ingresar recibe un token JWT firmado que dura <b>8 horas</b>. Se guarda solo en la pestaña (sessionStorage) y se envía en cada petición.</li>
        <li><b>Bloqueo:</b> <b>5 intentos fallidos</b> seguidos bloquean la cuenta <b>15 minutos</b>. Un ingreso correcto reinicia el contador.</li>
        <li><b>Autorización en cada petición:</b> el servidor no confía en el token para los permisos; consulta la base de datos en cada llamada. Quitar un menú o inactivar un usuario corta el acceso de inmediato.</li>
        <li><b>Mensajes genéricos:</b> el ingreso no revela si el usuario existe.</li>
        <li><b>Protección de la interfaz:</b> todo dato que viene del servidor se muestra escapado para evitar inyección de código (XSS).</li>
      </ul>`
  },
  {
    id: 'preguntas', titulo: 'Preguntas frecuentes', icono: 'patch-question',
    html: `
      <div class="doc-preguntas">
        <details><summary>No veo un módulo que necesito.</summary><p>Su usuario no tiene ese menú. Pida al administrador que se lo asigne en "Asignación de menús"; al volver a cargar la página aparecerá.</p></details>
        <details><summary>Me quitaron un menú y tenía la pantalla abierta, ¿qué pasa?</summary><p>La siguiente acción que haga contra ese módulo será rechazada por el servidor (403), porque los permisos se verifican en cada petición.</p></details>
        <details><summary>Mi cuenta quedó bloqueada.</summary><p>Espere 15 minutos desde el último intento fallido y vuelva a intentar con la contraseña correcta.</p></details>
        <details><summary>¿Por qué me devolvió a la pantalla de ingreso?</summary><p>Su token venció (8 horas), cerró la pestaña o el servidor lo rechazó. Ingrese de nuevo.</p></details>
        <details><summary>¿Puedo usar Atalaya desde el celular?</summary><p>Sí. El diseño se adapta: el menú se abre como cajón y las tablas se muestran como tarjetas.</p></details>
        <details><summary>¿Dónde está la documentación técnica del API?</summary><p>En <a href="swagger" target="_blank" rel="noopener">/swagger</a> encontrará todos los servicios, sus parámetros y respuestas.</p></details>
      </div>`
  },
  {
    id: 'api', titulo: 'Documentación del API', icono: 'braces',
    html: `
      <p>Atalaya expone un API REST en <code>/api</code>. La documentación interactiva (Swagger) está disponible en:</p>
      <p><a class="btn btn-primary" href="swagger" target="_blank" rel="noopener"><i class="bi bi-box-arrow-up-right" aria-hidden="true"></i> Abrir /swagger</a></p>
      <p>Todos los errores responden con el mismo formato: <code>{ estado, codigo, mensaje, detalles, traza }</code>.</p>`
  }
];

/**
 * @param {HTMLElement} el
 * @returns {Promise<Function>} limpieza (desconecta el observador)
 */
export async function mostrar(el) {
  el.innerHTML = `
    <div class="encabezado">
      <div><div class="antetitulo">Ayuda</div><h1>Manual de uso</h1><p>Todo lo que necesita para usar Atalaya, paso a paso.</p></div>
    </div>
    <div class="doc">
      <aside class="doc-indice" aria-label="Índice del manual">
        <div class="titulo">Contenido</div>
        <nav>${SECCIONES.map((s) => `<a href="#/manual" data-ir="${s.id}"><i class="bi bi-${s.icono}" aria-hidden="true"></i>${s.titulo}</a>`).join('')}</nav>
      </aside>
      <article class="tarjeta doc-contenido">
        ${SECCIONES.map((s) => `<section id="doc-${s.id}" aria-labelledby="h-${s.id}">
          <h2 id="h-${s.id}"><span class="sello-ico"><i class="bi bi-${s.icono}" aria-hidden="true"></i></span>${s.titulo}</h2>${s.html}</section>`).join('')}
      </article>
    </div>`;

  const enlaces = [...el.querySelectorAll('.doc-indice a')];
  const activar = (id) => enlaces.forEach((a) => {
    const si = a.dataset.ir === id;
    a.classList.toggle('activo', si);
    if (si) a.setAttribute('aria-current', 'true'); else a.removeAttribute('aria-current');
  });
  activar(SECCIONES[0].id);

  el.querySelector('.doc-indice').addEventListener('click', (e) => {
    const a = e.target.closest('a[data-ir]');
    if (!a) return;
    e.preventDefault();
    const destino = el.querySelector(`#doc-${a.dataset.ir}`);
    if (destino) { destino.scrollIntoView({ behavior: 'smooth', block: 'start' }); activar(a.dataset.ir); }
  });

  // Scrollspy: la sección visible más alta marca el índice.
  const visibles = new Map();
  const obs = new IntersectionObserver((entradas) => {
    entradas.forEach((en) => { if (en.isIntersecting) visibles.set(en.target.id, en.boundingClientRect.top); else visibles.delete(en.target.id); });
    const primero = [...visibles.entries()].sort((a, b) => a[1] - b[1])[0];
    if (primero) activar(primero[0].replace(/^doc-/, ''));
  }, { rootMargin: '-80px 0px -55% 0px' });
  el.querySelectorAll('.doc-contenido section').forEach((s) => obs.observe(s));
  return () => obs.disconnect();
}
