using System.Net;
using System.Web.Http;
using Atalaya.Dominio.Interfaces;
using Atalaya.Web.Filtros;
using Atalaya.Web.Seguridad;

namespace Atalaya.Web.Controllers
{
    /// <summary>
    /// Base de los controladores: acceso al usuario autenticado, IP, bitácora y errores con formato del contrato.
    /// </summary>
    public abstract class ControladorBase : ApiController
    {
        /// <summary>Id del usuario autenticado (o <c>null</c> en endpoints anónimos).</summary>
        protected int? IdUsuarioActual => ContextoPeticion.IdUsuario(User);

        /// <summary>Nombre de usuario del token.</summary>
        protected string LoginActual => ContextoPeticion.Login(User);

        /// <summary>Respuesta de error con el formato del contrato.</summary>
        /// <param name="estado">Código HTTP.</param>
        /// <param name="codigo">Código funcional.</param>
        /// <param name="mensaje">Mensaje legible.</param>
        protected IHttpActionResult Error(HttpStatusCode estado, string codigo, string mensaje)
        {
            return ResponseMessage(RespuestasError.Crear(Request, estado, codigo, mensaje));
        }

        /// <summary>Registra un evento en la bitácora a nombre del usuario autenticado.</summary>
        /// <param name="bitacora">Repositorio de bitácora.</param>
        /// <param name="evento">Código del evento.</param>
        /// <param name="detalle">Detalle (sin datos sensibles).</param>
        protected void Auditar(IRepositorioBitacora bitacora, string evento, string detalle)
        {
            RegistroBitacora.Registrar(bitacora, Request, evento, IdUsuarioActual, LoginActual, detalle);
        }
    }
}
