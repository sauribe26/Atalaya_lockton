using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Net.Http;
using System.Security.Claims;
using System.Security.Principal;
using System.Web;
using Atalaya.Dominio.Entidades;

namespace Atalaya.Web.Seguridad
{
    /// <summary>
    /// Utilidades para obtener del contexto de la petición el usuario autenticado y la IP del cliente.
    /// </summary>
    public static class ContextoPeticion
    {
        /// <summary>
        /// Id del usuario autenticado (claim <c>sub</c>), o <c>null</c> si la petición es anónima.
        /// </summary>
        public static int? IdUsuario(IPrincipal principal)
        {
            var claims = principal as ClaimsPrincipal;
            if (claims?.Identity == null || !claims.Identity.IsAuthenticated) return null;
            var sub = claims.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
            int id;
            return int.TryParse(sub, NumberStyles.Integer, CultureInfo.InvariantCulture, out id) ? id : (int?)null;
        }

        /// <summary>Nombre de usuario del token (claim <c>unique_name</c>).</summary>
        public static string Login(IPrincipal principal)
        {
            return (principal as ClaimsPrincipal)?.FindFirst(JwtRegisteredClaimNames.UniqueName)?.Value;
        }

        /// <summary>
        /// IP del cliente según la conexión TCP.
        /// </summary>
        /// <remarks>
        /// No se lee <c>X-Forwarded-For</c> a propósito: lo puede inventar cualquier cliente y la
        /// bitácora quedaría falseada. Si el sitio se publica detrás de un proxy de confianza, ese es
        /// el lugar para leerlo.
        /// </remarks>
        public static string Ip(HttpRequestMessage request)
        {
            object valor;
            if (request != null && request.Properties.TryGetValue("MS_HttpContext", out valor))
            {
                var contexto = valor as HttpContextBase;
                if (contexto?.Request != null) return contexto.Request.UserHostAddress;
            }
            return HttpContext.Current?.Request?.UserHostAddress;
        }

        /// <summary>Recurso para la bitácora: método y ruta (sin query string, que podría traer datos).</summary>
        public static string Recurso(HttpRequestMessage request)
        {
            return request == null ? null : request.Method.Method + " " + request.RequestUri.AbsolutePath;
        }

        /// <summary>Convierte el DTO completo al resumen que va en el login y en <c>/auth/yo</c>.</summary>
        public static UsuarioResumen Resumen(UsuarioDto u)
        {
            return new UsuarioResumen { Id = u.Id, Nombre = u.Nombre, Usuario = u.Usuario, Correo = u.Correo };
        }
    }
}
