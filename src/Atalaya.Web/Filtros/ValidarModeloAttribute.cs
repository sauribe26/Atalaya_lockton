using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Web.Http;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using System.Web.Http.ModelBinding;

namespace Atalaya.Web.Filtros
{
    /// <summary>
    /// Rechaza con 400 las peticiones cuyo modelo no pasa las DataAnnotations o que no traen cuerpo.
    /// </summary>
    /// <remarks>
    /// Se registra como filtro global para que ningún controlador olvide validar. El detalle se
    /// devuelve como diccionario <c>campo → mensaje</c> (en camelCase, igual que el JSON de entrada)
    /// para que el front pueda pintar el error junto al campo.
    /// </remarks>
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
    public class ValidarModeloAttribute : ActionFilterAttribute
    {
        /// <summary>Valida antes de ejecutar la acción.</summary>
        public override void OnActionExecuting(HttpActionContext actionContext)
        {
            var detalles = new Dictionary<string, string>();

            // Cuerpo ausente: Web API deja el parámetro en null sin marcar error.
            foreach (var parametro in actionContext.ActionDescriptor.GetParameters())
            {
                var esCuerpo = parametro.ParameterBinderAttribute is FromBodyAttribute ||
                               (!EsTipoSimple(parametro.ParameterType) && !(parametro.ParameterBinderAttribute is FromUriAttribute));
                object valor;
                if (esCuerpo && (!actionContext.ActionArguments.TryGetValue(parametro.ParameterName, out valor) || valor == null))
                {
                    detalles["cuerpo"] = "Envíe el cuerpo de la petición en JSON.";
                }
            }

            if (!actionContext.ModelState.IsValid)
            {
                foreach (var entrada in actionContext.ModelState.Where(e => e.Value.Errors.Count > 0))
                {
                    // Clave sin punto = el parámetro completo: el JSON no se pudo leer.
                    if (entrada.Key.IndexOf('.') < 0)
                    {
                        detalles["cuerpo"] = "El cuerpo no es un JSON válido.";
                        continue;
                    }
                    var campo = NombreCampo(entrada.Key);
                    if (detalles.ContainsKey(campo)) continue;
                    var error = entrada.Value.Errors.First();
                    detalles[campo] = !string.IsNullOrWhiteSpace(error.ErrorMessage)
                        ? error.ErrorMessage
                        : "Valor con formato inválido.";
                }
            }

            if (detalles.Count > 0)
            {
                actionContext.Response = RespuestasError.Crear(actionContext.Request, HttpStatusCode.BadRequest,
                    "VALIDACION", "La solicitud tiene datos inválidos.", detalles);
            }
        }

        /// <summary>
        /// Convierte la clave de ModelState (<c>solicitud.Correo</c>) en el nombre del campo JSON (<c>correo</c>).
        /// </summary>
        private static string NombreCampo(string clave)
        {
            if (string.IsNullOrEmpty(clave)) return "cuerpo";
            var punto = clave.IndexOf('.');
            var campo = punto >= 0 ? clave.Substring(punto + 1) : clave;
            if (string.IsNullOrEmpty(campo)) return "cuerpo";
            return char.ToLowerInvariant(campo[0]) + campo.Substring(1);
        }

        private static bool EsTipoSimple(Type tipo)
        {
            var t = Nullable.GetUnderlyingType(tipo) ?? tipo;
            return t.IsPrimitive || t.IsEnum || t == typeof(string) || t == typeof(decimal) ||
                   t == typeof(DateTime) || t == typeof(Guid) || t == typeof(TimeSpan) || t == typeof(DateTimeOffset);
        }
    }
}
