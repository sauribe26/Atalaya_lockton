using System.Collections.Generic;
using System.Net;
using System.Web.Http;
using System.Web.Http.Description;
using Atalaya.Dominio.Dtos;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Excepciones;
using Atalaya.Dominio.Interfaces;
using Atalaya.Dominio.Seguridad;
using Atalaya.Web.Seguridad;

namespace Atalaya.Web.Controllers
{
    /// <summary>
    /// Gestión de usuarios (menú <c>USUARIOS</c>).
    /// </summary>
    [RoutePrefix("api/users")]
    public class UsuariosController : ControladorBase
    {
        private readonly IRepositorioUsuarios _usuarios;
        private readonly IRepositorioBitacora _bitacora;

        /// <summary>Constructor usado por Web API.</summary>
        public UsuariosController() : this(Composicion.Usuarios(), Composicion.Bitacora()) { }

        /// <summary>Constructor con dependencias explícitas (pruebas).</summary>
        public UsuariosController(IRepositorioUsuarios usuarios, IRepositorioBitacora bitacora)
        {
            _usuarios = usuarios;
            _bitacora = bitacora;
        }

        /// <summary>
        /// Lista usuarios; <paramref name="buscar"/> filtra por nombre, usuario o correo.
        /// </summary>
        /// <param name="buscar">Texto a buscar (opcional).</param>
        /// <response code="200">Lista de usuarios.</response>
        /// <response code="401">Sin sesión.</response>
        /// <response code="403">Sin el menú USUARIOS.</response>
        [HttpGet, Route("")]
        [RequiereMenu(CodigosMenu.Usuarios)]
        [ResponseType(typeof(List<UsuarioDto>))]
        public IHttpActionResult Listar(string buscar = null)
        {
            return Ok(_usuarios.Listar(buscar));
        }

        /// <summary>
        /// Obtiene un usuario por id.
        /// </summary>
        /// <param name="id">Id del usuario.</param>
        /// <response code="200">Usuario.</response>
        /// <response code="404">USUARIO_NO_ENCONTRADO.</response>
        [HttpGet, Route("{id:int}", Name = "ObtenerUsuario")]
        [RequiereMenu(CodigosMenu.Usuarios)]
        [ResponseType(typeof(UsuarioDto))]
        public IHttpActionResult Obtener(int id)
        {
            return Ok(ObtenerOFallar(id));
        }

        /// <summary>
        /// Crea un usuario. La clave se guarda como hash PBKDF2 con sal propia; nunca en texto plano.
        /// </summary>
        /// <param name="solicitud">Datos del usuario nuevo.</param>
        /// <response code="201">Creado; el encabezado Location apunta al recurso.</response>
        /// <response code="400">VALIDACION, con detalle por campo.</response>
        /// <response code="409">USUARIO_DUPLICADO o CORREO_DUPLICADO.</response>
        [HttpPost, Route("")]
        [RequiereMenu(CodigosMenu.Usuarios)]
        [ResponseType(typeof(UsuarioDto))]
        public IHttpActionResult Crear([FromBody] SolicitudCrearUsuario solicitud)
        {
            var clave = HasherClaves.Derivar(solicitud.Clave);
            var id = _usuarios.Crear(solicitud.Nombre.Trim(), solicitud.Usuario.Trim(), solicitud.Correo.Trim().ToLowerInvariant(),
                clave, solicitud.Activo, IdUsuarioActual);

            Auditar(_bitacora, EventosBitacora.UsuarioCreado, "Creó el usuario " + solicitud.Usuario + " (id " + id + ")");

            var creado = ObtenerOFallar(id);
            return CreatedAtRoute("ObtenerUsuario", new { id }, creado);
        }

        /// <summary>
        /// Activa o inactiva un usuario.
        /// </summary>
        /// <remarks>
        /// Un usuario no puede inactivarse a sí mismo (409): evita que el único administrador se deje
        /// fuera del sistema por error. Al inactivar, el acceso se corta en la siguiente petición porque
        /// <c>[RequiereMenu]</c> consulta el estado en la BD.
        /// </remarks>
        /// <param name="id">Id del usuario.</param>
        /// <param name="solicitud">Nuevo estado.</param>
        /// <response code="200">Usuario actualizado.</response>
        /// <response code="404">USUARIO_NO_ENCONTRADO.</response>
        /// <response code="409">AUTOINACTIVACION.</response>
        [HttpPatch, Route("{id:int}/estado")]
        [RequiereMenu(CodigosMenu.Usuarios)]
        [ResponseType(typeof(UsuarioDto))]
        public IHttpActionResult CambiarEstado(int id, [FromBody] SolicitudCambiarEstado solicitud)
        {
            var activo = solicitud.Activo.Value;
            if (!activo && id == IdUsuarioActual)
            {
                throw new ConflictoException("AUTOINACTIVACION", "No puede inactivar su propio usuario.");
            }

            if (_usuarios.CambiarEstado(id, activo) == 0)
            {
                throw UsuarioNoEncontrado(id);
            }

            var usuario = ObtenerOFallar(id);
            Auditar(_bitacora, EventosBitacora.UsuarioEstado,
                (activo ? "Activó" : "Inactivó") + " al usuario " + usuario.Usuario + " (id " + id + ")");
            return Ok(usuario);
        }

        private UsuarioDto ObtenerOFallar(int id)
        {
            var usuario = _usuarios.Obtener(id);
            if (usuario == null) throw UsuarioNoEncontrado(id);
            return usuario;
        }

        private static NoEncontradoException UsuarioNoEncontrado(int id)
        {
            return new NoEncontradoException("USUARIO_NO_ENCONTRADO", "No existe el usuario con id " + id + ".");
        }
    }
}
