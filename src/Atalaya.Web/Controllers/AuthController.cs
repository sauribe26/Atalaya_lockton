using System;
using System.Net;
using System.Web.Http;
using System.Web.Http.Description;
using Atalaya.Dominio.Dtos;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Interfaces;
using Atalaya.Dominio.Seguridad;
using Atalaya.Web.Seguridad;

namespace Atalaya.Web.Controllers
{
    /// <summary>
    /// Inicio de sesión y datos del usuario autenticado.
    /// </summary>
    [RoutePrefix("api/auth")]
    public class AuthController : ControladorBase
    {
        private readonly IRepositorioUsuarios _usuarios;
        private readonly IRepositorioMenus _menus;
        private readonly IRepositorioBitacora _bitacora;
        private readonly ServicioJwt _jwt;

        /// <summary>Constructor usado por Web API (toma las implementaciones de <see cref="Composicion"/>).</summary>
        public AuthController()
            : this(Composicion.Usuarios(), Composicion.Menus(), Composicion.Bitacora(), Composicion.Jwt) { }

        /// <summary>Constructor con dependencias explícitas (pruebas).</summary>
        public AuthController(IRepositorioUsuarios usuarios, IRepositorioMenus menus, IRepositorioBitacora bitacora, ServicioJwt jwt)
        {
            _usuarios = usuarios;
            _menus = menus;
            _bitacora = bitacora;
            _jwt = jwt;
        }

        /// <summary>
        /// Inicia sesión con usuario o correo y devuelve el JWT junto con el menú dinámico.
        /// </summary>
        /// <remarks>
        /// Orden de las comprobaciones (importa para la seguridad):
        /// 1) Si el usuario no existe se responde exactamente igual que con clave equivocada (401
        ///    CREDENCIALES_INVALIDAS) y se gasta el mismo tiempo de cálculo, para no revelar qué usuarios existen.
        /// 2) Si la cuenta está bloqueada se responde 423 SIN comparar la clave: así un atacante no puede
        ///    seguir probando claves durante el bloqueo.
        /// 3) Se compara la clave; si falla, el SP suma el intento y aplica el bloqueo (5 fallos → 15 min).
        /// 4) Solo con la clave correcta se informa si el usuario está inactivo (403).
        /// </remarks>
        /// <param name="solicitud">Usuario o correo, y clave.</param>
        /// <response code="200">Token, usuario y menús.</response>
        /// <response code="400">Faltan datos.</response>
        /// <response code="401">CREDENCIALES_INVALIDAS.</response>
        /// <response code="403">USUARIO_INACTIVO.</response>
        /// <response code="423">USUARIO_BLOQUEADO (el mensaje incluye los minutos restantes).</response>
        [HttpPost, Route("login")]
        [ResponseType(typeof(RespuestaLogin))]
        public IHttpActionResult Login([FromBody] SolicitudLogin solicitud)
        {
            var login = solicitud.Login.Trim();
            var ip = ContextoPeticion.Ip(Request);
            var usuario = _usuarios.ObtenerParaLogin(login);

            if (usuario == null)
            {
                HasherClaves.SimularVerificacion(solicitud.Clave);
                RegistroBitacora.Registrar(_bitacora, Request, EventosBitacora.LoginFallido, null, login, "Usuario inexistente");
                return CredencialesInvalidas();
            }

            if (EstaBloqueado(usuario.BloqueadoHasta))
            {
                RegistroBitacora.Registrar(_bitacora, Request, EventosBitacora.LoginBloqueado, usuario.Id, usuario.Usuario,
                    "Intento sobre cuenta bloqueada");
                return Bloqueado(usuario.BloqueadoHasta.Value);
            }

            if (!HasherClaves.Verificar(solicitud.Clave, usuario.HashClave, usuario.SalClave, usuario.Iteraciones))
            {
                var intento = _usuarios.RegistrarLogin(usuario.Id, false, ip);
                RegistroBitacora.Registrar(_bitacora, Request, EventosBitacora.LoginFallido, usuario.Id, usuario.Usuario,
                    "Clave incorrecta (intento " + intento.IntentosFallidos + ")");

                if (EstaBloqueado(intento.BloqueadoHasta))
                {
                    RegistroBitacora.Registrar(_bitacora, Request, EventosBitacora.LoginBloqueado, usuario.Id, usuario.Usuario,
                        "Cuenta bloqueada por intentos fallidos");
                    return Bloqueado(intento.BloqueadoHasta.Value);
                }
                return CredencialesInvalidas();
            }

            if (!usuario.Activo)
            {
                RegistroBitacora.Registrar(_bitacora, Request, EventosBitacora.LoginFallido, usuario.Id, usuario.Usuario, "Usuario inactivo");
                return Error(HttpStatusCode.Forbidden, "USUARIO_INACTIVO", "El usuario está inactivo. Contacte al administrador.");
            }

            _usuarios.RegistrarLogin(usuario.Id, true, ip);
            RegistroBitacora.Registrar(_bitacora, Request, EventosBitacora.LoginOk, usuario.Id, usuario.Usuario, null);

            var resumen = new UsuarioResumen { Id = usuario.Id, Nombre = usuario.Nombre, Usuario = usuario.Usuario, Correo = usuario.Correo };
            DateTime expira;
            var token = _jwt.Emitir(resumen, out expira);

            return Ok(new RespuestaLogin
            {
                Token = token,
                ExpiraEn = expira,
                Usuario = resumen,
                Menus = _menus.ListarDeUsuario(usuario.Id)
            });
        }

        /// <summary>
        /// Devuelve el usuario autenticado y sus menús actuales (con ellos el front arma la barra lateral).
        /// </summary>
        /// <remarks>
        /// Los menús se leen de la BD en este momento, no del token: si un administrador cambia la
        /// asignación, basta recargar la página para verla. Si el usuario fue inactivado se responde 401
        /// para que el front cierre la sesión.
        /// </remarks>
        /// <response code="200">Usuario y menús.</response>
        /// <response code="401">Sin token, token inválido/expirado o usuario inactivo.</response>
        [HttpGet, Route("yo")]
        [RequiereAutenticacion]
        [ResponseType(typeof(RespuestaYo))]
        public IHttpActionResult Yo()
        {
            var usuario = _usuarios.Obtener(IdUsuarioActual.Value);
            if (usuario == null || !usuario.Activo)
            {
                return Error(HttpStatusCode.Unauthorized, "SESION_INVALIDA", "Su usuario ya no está activo. Inicie sesión de nuevo.");
            }
            return Ok(new RespuestaYo
            {
                Usuario = ContextoPeticion.Resumen(usuario),
                Menus = _menus.ListarDeUsuario(usuario.Id)
            });
        }

        private static bool EstaBloqueado(DateTime? hasta)
        {
            return hasta.HasValue && hasta.Value > DateTime.Now;
        }

        private IHttpActionResult CredencialesInvalidas()
        {
            return Error(HttpStatusCode.Unauthorized, "CREDENCIALES_INVALIDAS", "Usuario o clave incorrectos.");
        }

        private IHttpActionResult Bloqueado(DateTime hasta)
        {
            var minutos = Math.Max(1, (int)Math.Ceiling((hasta - DateTime.Now).TotalMinutes));
            return Error((HttpStatusCode)423, "USUARIO_BLOQUEADO",
                "La cuenta está bloqueada por intentos fallidos. Intente de nuevo en " + minutos +
                (minutos == 1 ? " minuto." : " minutos."));
        }
    }
}
