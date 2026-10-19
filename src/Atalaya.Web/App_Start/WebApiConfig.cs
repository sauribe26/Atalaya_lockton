using System.Web.Http;
using System.Web.Http.ExceptionHandling;
using Atalaya.Web.Filtros;
using Atalaya.Web.Seguridad;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace Atalaya.Web
{
    /// <summary>
    /// Configuración de Web API: rutas, serialización, seguridad y manejo de errores.
    /// </summary>
    public static class WebApiConfig
    {
        /// <summary>
        /// Registra todo el pipeline de la API.
        /// </summary>
        /// <param name="config">Configuración global de Web API.</param>
        public static void Register(HttpConfiguration config)
        {
            // Rutas por atributo: cada controlador declara su URL junto a la acción, más fácil de leer.
            config.MapHttpAttributeRoutes();

            // Cualquier /api/... que no exista responde 404 con el formato de error del contrato
            // (sin esto IIS devolvería su página HTML). Se registra después de las rutas reales.
            config.Routes.MapHttpRoute(
                name: "ApiNoEncontrada",
                routeTemplate: "api/{*resto}",
                defaults: null,
                constraints: null,
                handler: new RutaNoEncontradaHandler());

            // Solo JSON: el XML no se usa y quitarlo evita que un navegador reciba XML por su Accept.
            config.Formatters.Remove(config.Formatters.XmlFormatter);
            var json = config.Formatters.JsonFormatter.SerializerSettings;
            json.ContractResolver = new CamelCasePropertyNamesContractResolver();
            json.DateFormatHandling = DateFormatHandling.IsoDateFormat;
            json.DateTimeZoneHandling = DateTimeZoneHandling.RoundtripKind;
            json.NullValueHandling = NullValueHandling.Include;
            json.Formatting = Formatting.None;

            // Nunca devolver detalles de excepción al cliente (stack traces), ni siquiera en local.
            config.IncludeErrorDetailPolicy = IncludeErrorDetailPolicy.Never;

            // Orden de los handlers: el primero envuelve a los demás.
            // 1) Normaliza errores propios de Web API (405, 415...) al formato del contrato y agrega no-store.
            // 2) Lee y valida el JWT; deja el principal listo para los filtros de autorización.
            config.MessageHandlers.Add(new NormalizadorRespuestasHandler());
            config.MessageHandlers.Add(new AutenticacionJwtHandler(Composicion.Jwt));

            // Validación de entrada para todas las acciones (400 con detalle por campo).
            config.Filters.Add(new ValidarModeloAttribute());

            // Errores no controlados → formato del contrato.
            config.Services.Replace(typeof(IExceptionHandler), new ManejadorErroresGlobal());

            SwaggerConfig.Registrar(config);
        }
    }
}
