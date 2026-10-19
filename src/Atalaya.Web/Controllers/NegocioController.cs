using System.Collections.Generic;
using System.Web.Http;
using System.Web.Http.Description;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Interfaces;
using Atalaya.Dominio.Seguridad;
using Atalaya.Web.Seguridad;

namespace Atalaya.Web.Controllers
{
    /// <summary>
    /// Datos de negocio demo del broker. Cada listado exige su propio menú, para demostrar que
    /// la autorización es por menú y no por "estar logueado".
    /// </summary>
    [RoutePrefix("api")]
    public class NegocioController : ControladorBase
    {
        private readonly IRepositorioNegocio _negocio;

        /// <summary>Constructor usado por Web API.</summary>
        public NegocioController() : this(Composicion.Negocio()) { }

        /// <summary>Constructor con dependencias explícitas (pruebas).</summary>
        public NegocioController(IRepositorioNegocio negocio)
        {
            _negocio = negocio;
        }

        /// <summary>Clientes con su número de pólizas vigentes (menú CLIENTES).</summary>
        /// <response code="200">Clientes.</response>
        /// <response code="403">Sin el menú CLIENTES.</response>
        [HttpGet, Route("clientes")]
        [RequiereMenu(CodigosMenu.Clientes)]
        [ResponseType(typeof(List<Cliente>))]
        public IHttpActionResult Clientes()
        {
            return Ok(_negocio.ListarClientes());
        }

        /// <summary>Pólizas con días para vencer (menú POLIZAS). Las primas van como entero en pesos.</summary>
        /// <response code="200">Pólizas.</response>
        /// <response code="403">Sin el menú POLIZAS.</response>
        [HttpGet, Route("polizas")]
        [RequiereMenu(CodigosMenu.Polizas)]
        [ResponseType(typeof(List<Poliza>))]
        public IHttpActionResult Polizas()
        {
            return Ok(_negocio.ListarPolizas());
        }

        /// <summary>Siniestros con póliza y cliente (menú SINIESTROS).</summary>
        /// <response code="200">Siniestros.</response>
        /// <response code="403">Sin el menú SINIESTROS.</response>
        [HttpGet, Route("siniestros")]
        [RequiereMenu(CodigosMenu.Siniestros)]
        [ResponseType(typeof(List<Siniestro>))]
        public IHttpActionResult Siniestros()
        {
            return Ok(_negocio.ListarSiniestros());
        }
    }
}
