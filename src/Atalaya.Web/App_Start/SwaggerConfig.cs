using System;
using System.IO;
using System.Web.Http;
using Swashbuckle.Application;

namespace Atalaya.Web
{
    /// <summary>
    /// Documentación interactiva con Swashbuckle (Swagger 2.0). UI en <c>/swagger</c>, JSON en <c>/swagger/docs/v1</c>.
    /// </summary>
    public static class SwaggerConfig
    {
        /// <summary>
        /// Registra Swagger y su interfaz.
        /// </summary>
        /// <param name="config">Configuración de Web API.</param>
        /// <remarks>
        /// Se declara un esquema <c>apiKey</c> en el encabezado <c>Authorization</c>: en la UI se pega
        /// <c>Bearer &lt;token&gt;</c> una sola vez y queda aplicado a todas las peticiones de prueba.
        /// Los comentarios XML (///) de controladores y DTOs se publican como descripción de cada operación.
        /// </remarks>
        public static void Registrar(HttpConfiguration config)
        {
            config
                .EnableSwagger(c =>
                {
                    c.SingleApiVersion("v1", "Atalaya API")
                        .Description("Control de acceso por menús (usuarios, asignación, auditoría) y datos demo de un broker de seguros. " +
                                     "Autentíquese con POST /api/auth/login y pegue 'Bearer <token>' en el botón de API key.");

                    c.ApiKey("Bearer")
                        .Description("JWT en el encabezado Authorization. Formato: Bearer <token>")
                        .Name("Authorization")
                        .In("header");

                    IncluirXml(c, "Atalaya.Web.xml");
                    IncluirXml(c, "Atalaya.Dominio.xml");

                    c.DescribeAllEnumsAsStrings();
                })
                .EnableSwaggerUi(c =>
                {
                    c.DocumentTitle("Atalaya API");
                    c.EnableApiKeySupport("Authorization", "header");
                });
        }

        private static void IncluirXml(SwaggerDocsConfig c, string archivo)
        {
            var ruta = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bin", archivo);
            if (File.Exists(ruta))
            {
                c.IncludeXmlComments(ruta);
            }
        }
    }
}
