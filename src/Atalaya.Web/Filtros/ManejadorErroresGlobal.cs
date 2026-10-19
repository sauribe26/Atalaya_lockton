using System.Diagnostics;
using System.Net;
using System.Web.Http.ExceptionHandling;
using System.Web.Http.Results;
using Atalaya.Dominio.Excepciones;

namespace Atalaya.Web.Filtros
{
    /// <summary>
    /// Convierte cualquier excepción no controlada en una respuesta con el formato de error del contrato.
    /// </summary>
    /// <remarks>
    /// <para>Se usa <see cref="ExceptionHandler"/> (y no solo un ExceptionFilter) porque también atrapa
    /// errores que ocurren fuera de las acciones: en filtros de autorización, en message handlers o al
    /// serializar.</para>
    /// <para>Errores de negocio (<see cref="ExcepcionNegocio"/>) se responden con su código y mensaje.
    /// Cualquier otro error es un 500 genérico: el detalle técnico va al log del servidor con un id de
    /// traza, y al cliente solo le llega ese id. Así no se filtran stack traces, nombres de tablas ni
    /// cadenas de conexión.</para>
    /// </remarks>
    public class ManejadorErroresGlobal : ExceptionHandler
    {
        /// <summary>Maneja todas las excepciones, no solo las de nivel superior.</summary>
        public override bool ShouldHandle(ExceptionHandlerContext context)
        {
            return true;
        }

        /// <summary>Traduce la excepción a la respuesta HTTP.</summary>
        public override void Handle(ExceptionHandlerContext context)
        {
            var request = context.Request;
            var traza = RespuestasError.NuevaTraza();
            var negocio = context.Exception as ExcepcionNegocio;

            if (negocio != null)
            {
                context.Result = new ResponseMessageResult(RespuestasError.Crear(request, (HttpStatusCode)negocio.EstadoHttp,
                    negocio.Codigo, negocio.Message, negocio.Detalles, traza));
                return;
            }

            Trace.TraceError("[traza {0}] {1} {2}: {3}", traza, request?.Method, request?.RequestUri?.AbsolutePath, context.Exception);

            context.Result = new ResponseMessageResult(RespuestasError.Crear(request, HttpStatusCode.InternalServerError,
                "ERROR_INTERNO", "Ocurrió un error inesperado. Si persiste, informe el código de traza.", null, traza));
        }
    }
}
