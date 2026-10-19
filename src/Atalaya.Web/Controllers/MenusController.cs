using System.Collections.Generic;
using System.Linq;
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
    /// Catálogo de menús y asignación de menús a usuarios (menú <c>ASIGNACION</c>).
    /// </summary>
    [RoutePrefix("api")]
    public class MenusController : ControladorBase
    {
        private readonly IRepositorioMenus _menus;
        private readonly IRepositorioUsuarios _usuarios;
        private readonly IRepositorioBitacora _bitacora;

        /// <summary>Constructor usado por Web API.</summary>
        public MenusController() : this(Composicion.Menus(), Composicion.Usuarios(), Composicion.Bitacora()) { }

        /// <summary>Constructor con dependencias explícitas (pruebas).</summary>
        public MenusController(IRepositorioMenus menus, IRepositorioUsuarios usuarios, IRepositorioBitacora bitacora)
        {
            _menus = menus;
            _usuarios = usuarios;
            _bitacora = bitacora;
        }

        /// <summary>
        /// Catálogo de menús activos con la cantidad de usuarios que tiene cada uno.
        /// </summary>
        /// <response code="200">Menús.</response>
        /// <response code="403">Sin el menú ASIGNACION.</response>
        [HttpGet, Route("menus")]
        [RequiereMenu(CodigosMenu.Asignacion)]
        [ResponseType(typeof(List<MenuDto>))]
        public IHttpActionResult Listar()
        {
            return Ok(_menus.Listar(true));
        }

        /// <summary>
        /// Menús asignados a un usuario. Lo puede consultar quien tenga ASIGNACION o el propio usuario.
        /// </summary>
        /// <param name="id">Id del usuario.</param>
        /// <response code="200">Menús del usuario.</response>
        /// <response code="404">USUARIO_NO_ENCONTRADO.</response>
        [HttpGet, Route("users/{id:int}/menus")]
        [RequiereMenu(CodigosMenu.Asignacion, PermitirPropioUsuario = true)]
        [ResponseType(typeof(List<MenuDto>))]
        public IHttpActionResult MenusDeUsuario(int id)
        {
            ValidarUsuarioExiste(id);
            return Ok(_menus.ListarDeUsuario(id));
        }

        /// <summary>
        /// Reemplaza la asignación completa de menús de un usuario.
        /// </summary>
        /// <remarks>
        /// Se envía la lista final (no altas/bajas sueltas): el SP calcula la diferencia en una transacción.
        /// Reglas: todos los ids deben existir y estar activos (400); un usuario no puede quitarse a sí mismo
        /// ASIGNACION (409 AUTOBLOQUEO), porque quedaría sin forma de deshacer el cambio.
        /// </remarks>
        /// <param name="id">Id del usuario.</param>
        /// <param name="solicitud">Ids de menú que deben quedar asignados.</param>
        /// <response code="200">Agregados, retirados y asignación resultante.</response>
        /// <response code="400">MENUS_INEXISTENTES.</response>
        /// <response code="404">USUARIO_NO_ENCONTRADO.</response>
        /// <response code="409">AUTOBLOQUEO.</response>
        [HttpPut, Route("users/{id:int}/menus")]
        [RequiereMenu(CodigosMenu.Asignacion)]
        [ResponseType(typeof(ResultadoAsignacion))]
        public IHttpActionResult Reemplazar(int id, [FromBody] SolicitudAsignarMenus solicitud)
        {
            var usuario = ValidarUsuarioExiste(id);
            var ids = solicitud.MenuIds.Distinct().ToList();

            var catalogo = _menus.Listar(true);
            var inexistentes = ids.Where(m => catalogo.All(c => c.Id != m)).ToList();
            if (inexistentes.Count > 0)
            {
                throw new SolicitudInvalidaException("MENUS_INEXISTENTES", "Hay menús que no existen o están inactivos.",
                    new Dictionary<string, string> { { "menuIds", "Ids no válidos: " + string.Join(", ", inexistentes) } });
            }

            if (id == IdUsuarioActual)
            {
                var asignacion = catalogo.First(c => c.Codigo == CodigosMenu.Asignacion);
                if (!ids.Contains(asignacion.Id))
                {
                    throw new ConflictoException("AUTOBLOQUEO", "No puede quitarse a sí mismo el menú de Asignación de menús.");
                }
            }

            var resultado = _menus.Reemplazar(id, ids, IdUsuarioActual);
            resultado.Menus = _menus.ListarDeUsuario(id);

            Auditar(_bitacora, EventosBitacora.MenusActualizados,
                "Usuario " + usuario.Usuario + ": +" + resultado.Agregados + " / -" + resultado.Retirados +
                " → [" + string.Join(",", resultado.Menus.Select(m => m.Codigo)) + "]");

            return Ok(resultado);
        }

        private UsuarioDto ValidarUsuarioExiste(int id)
        {
            var usuario = _usuarios.Obtener(id);
            if (usuario == null)
            {
                throw new NoEncontradoException("USUARIO_NO_ENCONTRADO", "No existe el usuario con id " + id + ".");
            }
            return usuario;
        }
    }
}
