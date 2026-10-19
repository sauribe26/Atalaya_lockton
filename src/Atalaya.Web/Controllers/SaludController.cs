using System;
using System.Net;
using System.Web.Http;
using System.Web.Http.Description;
using Atalaya.Dominio.Dtos;
using Atalaya.Dominio.Interfaces;

namespace Atalaya.Web.Controllers
{
    /// <summary>
    /// Verificación de salud (anónima) para monitoreo y para comprobar la instalación.
    /// </summary>
    public class SaludController : ControladorBase
    {
        private readonly IVerificadorSalud _verificador;

        /// <summary>Constructor usado por Web API.</summary>
        public SaludController() : this(Composicion.Salud()) { }

        /// <summary>Constructor con dependencias explícitas (pruebas).</summary>
        public SaludController(IVerificadorSalud verificador)
        {
            _verificador = verificador;
        }

        /// <summary>
        /// Indica si la API y la base de datos responden. No expone versiones ni datos de conexión.
        /// </summary>
        /// <response code="200">Todo responde.</response>
        /// <response code="503">La base de datos no responde.</response>
        [HttpGet, Route("api/salud")]
        [ResponseType(typeof(EstadoSalud))]
        public IHttpActionResult Obtener()
        {
            var bdOk = _verificador.BaseDatosDisponible();
            var estado = new EstadoSalud
            {
                Estado = bdOk ? "ok" : "degradado",
                BaseDatos = bdOk ? "ok" : "error",
                Hora = DateTime.Now
            };
            return bdOk ? (IHttpActionResult)Ok(estado) : Content(HttpStatusCode.ServiceUnavailable, estado);
        }
    }
}
