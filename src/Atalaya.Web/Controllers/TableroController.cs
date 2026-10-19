using System.Web.Http;
using System.Web.Http.Description;
using Atalaya.Dominio.Dtos;
using Atalaya.Dominio.Interfaces;
using Atalaya.Dominio.Seguridad;
using Atalaya.Web.Seguridad;

namespace Atalaya.Web.Controllers
{
    /// <summary>
    /// Tablero de indicadores de acceso (menú <c>TABLERO</c>).
    /// </summary>
    public class TableroController : ControladorBase
    {
        private readonly IRepositorioTablero _tablero;

        /// <summary>Constructor usado por Web API.</summary>
        public TableroController() : this(Composicion.Tablero()) { }

        /// <summary>Constructor con dependencias explícitas (pruebas).</summary>
        public TableroController(IRepositorioTablero tablero)
        {
            _tablero = tablero;
        }

        /// <summary>
        /// KPIs, serie de 14 días, uso por menú y matriz usuario × menú, en una sola llamada.
        /// </summary>
        /// <response code="200">Datos del tablero.</response>
        /// <response code="403">Sin el menú TABLERO.</response>
        [HttpGet, Route("api/tablero")]
        [RequiereMenu(CodigosMenu.Tablero)]
        [ResponseType(typeof(Tablero))]
        public IHttpActionResult Obtener()
        {
            return Ok(_tablero.Obtener());
        }
    }
}
