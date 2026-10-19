using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Http;

namespace Atalaya.Web.Filtros
{
    /// <summary>
    /// Último paso de cada respuesta de la API: unifica errores propios de Web API y evita caché.
    /// </summary>
    /// <remarks>
    /// Web API genera algunos errores por su cuenta (405 método no permitido, 415 tipo de contenido,
    /// 404 de acción) con su formato <c>{"Message": ...}</c>. Aquí se reemplazan por el formato del contrato.
    /// Además se marca <c>Cache-Control: no-store</c> porque las respuestas traen datos personales.
    /// </remarks>
    public class NormalizadorRespuestasHandler : DelegatingHandler
    {
        /// <summary>Procesa la respuesta después de que el resto del pipeline la generó.</summary>
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var respuesta = await base.SendAsync(request, cancellationToken);

            var contenido = respuesta.Content as ObjectContent;
            if (!respuesta.IsSuccessStatusCode && contenido?.Value is HttpError)
            {
                string codigo, mensaje;
                switch (respuesta.StatusCode)
                {
                    case HttpStatusCode.NotFound:
                        codigo = "RECURSO_NO_ENCONTRADO"; mensaje = "La ruta solicitada no existe en la API."; break;
                    case HttpStatusCode.MethodNotAllowed:
                        codigo = "METODO_NO_PERMITIDO"; mensaje = "El método HTTP no está permitido en esta ruta."; break;
                    case HttpStatusCode.UnsupportedMediaType:
                        codigo = "TIPO_CONTENIDO_NO_SOPORTADO"; mensaje = "Envíe el cuerpo como application/json."; break;
                    case HttpStatusCode.BadRequest:
                        codigo = "SOLICITUD_INVALIDA"; mensaje = "La solicitud no es válida."; break;
                    default:
                        codigo = "ERROR_HTTP"; mensaje = "No se pudo procesar la solicitud."; break;
                }
                var nueva = RespuestasError.Crear(request, respuesta.StatusCode, codigo, mensaje);
                foreach (var h in respuesta.Content.Headers.Allow) nueva.Content.Headers.Allow.Add(h);
                respuesta.Dispose();
                respuesta = nueva;
            }

            if (respuesta.Headers.CacheControl == null)
            {
                respuesta.Headers.CacheControl = new CacheControlHeaderValue { NoStore = true, NoCache = true };
            }
            return respuesta;
        }
    }

    /// <summary>
    /// Handler de la ruta comodín <c>api/{*resto}</c>: responde 404 en el formato del contrato.
    /// </summary>
    public class RutaNoEncontradaHandler : HttpMessageHandler
    {
        /// <summary>Devuelve siempre 404.</summary>
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(RespuestasError.Crear(request, HttpStatusCode.NotFound,
                "RECURSO_NO_ENCONTRADO", "La ruta solicitada no existe en la API."));
        }
    }
}
