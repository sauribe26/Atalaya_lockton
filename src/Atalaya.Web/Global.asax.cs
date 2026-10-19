using System;
using System.Web;
using System.Web.Http;

namespace Atalaya.Web
{
    /// <summary>
    /// Punto de arranque de la aplicación en IIS.
    /// </summary>
    public class WebApiApplication : HttpApplication
    {
        /// <summary>
        /// Se ejecuta una vez al iniciar el sitio: valida secretos y registra Web API.
        /// </summary>
        /// <remarks>
        /// La validación de la clave JWT va primero a propósito: si falta, el sitio no arranca y el
        /// mensaje dice exactamente qué archivo completar, en vez de fallar en el primer login.
        /// </remarks>
        protected void Application_Start()
        {
            Composicion.Inicializar();
            GlobalConfiguration.Configure(WebApiConfig.Register);
        }

        /// <summary>
        /// Quita el encabezado <c>Server</c> para no anunciar la versión de IIS.
        /// </summary>
        protected void Application_PreSendRequestHeaders(object sender, EventArgs e)
        {
            var app = sender as HttpApplication;
            app?.Context?.Response.Headers.Remove("Server");
        }
    }
}
