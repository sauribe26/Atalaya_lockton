using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Web.Http;
using System.Web.Http.Description;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Excepciones;
using Atalaya.Dominio.Interfaces;
using Atalaya.Dominio.Seguridad;
using Atalaya.Web.Seguridad;

namespace Atalaya.Web.Controllers
{
    /// <summary>
    /// Consulta de la bitácora de accesos (menú <c>AUDITORIA</c>).
    /// </summary>
    public class AuditoriaController : ControladorBase
    {
        private const int LimiteMaximo = 1000;
        private static readonly Regex FormatoEvento = new Regex("^[A-Za-z_]{1,30}$", RegexOptions.Compiled);

        private readonly IRepositorioBitacora _bitacora;

        /// <summary>Constructor usado por Web API.</summary>
        public AuditoriaController() : this(Composicion.Bitacora()) { }

        /// <summary>Constructor con dependencias explícitas (pruebas).</summary>
        public AuditoriaController(IRepositorioBitacora bitacora)
        {
            _bitacora = bitacora;
        }

        /// <summary>
        /// Últimos eventos de la bitácora, del más reciente al más antiguo.
        /// </summary>
        /// <param name="evento">Código del evento (ej. ACCESO_DENEGADO); vacío = todos.</param>
        /// <param name="limite">Máximo de filas (1 a 1000, por defecto 200). Se acota para no traer la tabla entera.</param>
        /// <response code="200">Eventos.</response>
        /// <response code="400">Parámetros inválidos.</response>
        /// <response code="403">Sin el menú AUDITORIA.</response>
        [HttpGet, Route("api/auditoria")]
        [RequiereMenu(CodigosMenu.Auditoria)]
        [ResponseType(typeof(List<EventoBitacora>))]
        public IHttpActionResult Listar(string evento = null, int limite = 200)
        {
            if (!string.IsNullOrWhiteSpace(evento) && !FormatoEvento.IsMatch(evento.Trim()))
            {
                throw new SolicitudInvalidaException("VALIDACION", "El código de evento no es válido.",
                    new Dictionary<string, string> { { "evento", "Use un código como LOGIN_OK o ACCESO_DENEGADO." } });
            }
            if (limite < 1) limite = 1;
            if (limite > LimiteMaximo) limite = LimiteMaximo;

            return Ok(_bitacora.Listar(evento, limite));
        }
    }
}
