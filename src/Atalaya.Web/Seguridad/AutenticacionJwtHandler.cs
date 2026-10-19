using System;
using System.Diagnostics;
using System.Net.Http;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using Microsoft.IdentityModel.Tokens;

namespace Atalaya.Web.Seguridad
{
    /// <summary>
    /// Lee el encabezado <c>Authorization: Bearer</c> de cada petición y, si el token es válido,
    /// deja el usuario autenticado en el contexto.
    /// </summary>
    /// <remarks>
    /// Este handler solo AUTENTICA; no rechaza nada. Rechazar (401/403) es tarea de los filtros
    /// <see cref="RequiereAutenticacionAttribute"/> y <see cref="RequiereMenuAttribute"/>, así los
    /// endpoints anónimos (login, salud, Swagger) siguen funcionando aunque llegue un token vencido.
    /// Si el token falla, se guarda el motivo para que el 401 diga si expiró o es inválido.
    /// </remarks>
    public class AutenticacionJwtHandler : DelegatingHandler
    {
        /// <summary>Clave en <c>Request.Properties</c> con el motivo del fallo del token.</summary>
        public const string PropiedadErrorToken = "atalaya.errorToken";

        private readonly ServicioJwt _jwt;

        /// <summary>Crea el handler.</summary>
        /// <param name="jwt">Servicio de validación de tokens.</param>
        public AutenticacionJwtHandler(ServicioJwt jwt)
        {
            _jwt = jwt ?? throw new ArgumentNullException(nameof(jwt));
        }

        /// <summary>Valida el token (si viene) y continúa con la petición.</summary>
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var encabezado = request.Headers.Authorization;
            if (encabezado != null &&
                string.Equals(encabezado.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase) &&
                !string.IsNullOrWhiteSpace(encabezado.Parameter))
            {
                try
                {
                    var principal = _jwt.Validar(encabezado.Parameter.Trim());
                    EstablecerPrincipal(request, principal);
                }
                catch (SecurityTokenExpiredException)
                {
                    request.Properties[PropiedadErrorToken] = "TOKEN_EXPIRADO";
                }
                catch (Exception ex) when (ex is SecurityTokenException || ex is ArgumentException)
                {
                    // ArgumentException: el texto ni siquiera tiene forma de JWT.
                    Trace.TraceInformation("Token rechazado: {0}", ex.GetType().Name);
                    request.Properties[PropiedadErrorToken] = "TOKEN_INVALIDO";
                }
            }
            return base.SendAsync(request, cancellationToken);
        }

        private static void EstablecerPrincipal(HttpRequestMessage request, ClaimsPrincipal principal)
        {
            var contexto = request.GetRequestContext();
            if (contexto != null) contexto.Principal = principal;
            Thread.CurrentPrincipal = principal;
            if (HttpContext.Current != null) HttpContext.Current.User = principal;
        }
    }
}
