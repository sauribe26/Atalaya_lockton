using System;
using System.Net;
using System.Net.Http.Headers;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using Atalaya.Web.Filtros;

namespace Atalaya.Web.Seguridad
{
    /// <summary>
    /// Exige un JWT válido. Responde 401 con el formato de error del contrato si no lo hay.
    /// </summary>
    /// <remarks>
    /// Se usa en vez de <c>[Authorize]</c> porque el de Web API responde con su propio JSON
    /// (<c>{"Message":...}</c>) y aquí se necesita el formato uniforme y el motivo (expirado/inválido).
    /// </remarks>
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false, Inherited = true)]
    public class RequiereAutenticacionAttribute : AuthorizationFilterAttribute
    {
        /// <summary>Corta la petición con 401 si no hay usuario autenticado.</summary>
        public override void OnAuthorization(HttpActionContext actionContext)
        {
            if (ContextoPeticion.IdUsuario(actionContext.RequestContext.Principal) == null)
            {
                actionContext.Response = Responder401(actionContext);
            }
        }

        /// <summary>
        /// Construye el 401 indicando si el token faltó, expiró o es inválido.
        /// </summary>
        internal static System.Net.Http.HttpResponseMessage Responder401(HttpActionContext actionContext)
        {
            var request = actionContext.Request;
            object motivo;
            request.Properties.TryGetValue(AutenticacionJwtHandler.PropiedadErrorToken, out motivo);

            string codigo, mensaje;
            switch (motivo as string)
            {
                case "TOKEN_EXPIRADO":
                    codigo = "TOKEN_EXPIRADO";
                    mensaje = "La sesión expiró. Inicie sesión de nuevo.";
                    break;
                case "TOKEN_INVALIDO":
                    codigo = "TOKEN_INVALIDO";
                    mensaje = "El token de acceso no es válido.";
                    break;
                default:
                    codigo = "NO_AUTENTICADO";
                    mensaje = "Debe iniciar sesión para usar este recurso.";
                    break;
            }

            var respuesta = RespuestasError.Crear(request, HttpStatusCode.Unauthorized, codigo, mensaje);
            respuesta.Headers.WwwAuthenticate.Add(new AuthenticationHeaderValue("Bearer"));
            return respuesta;
        }
    }
}
