using System.Configuration;
using MySql.Data.MySqlClient;

namespace Atalaya.Datos
{
    /// <summary>
    /// Crea conexiones MySQL a partir de la cadena <c>Atalaya</c> del Web.config.
    /// </summary>
    /// <remarks>
    /// La cadena real vive en <c>ConnectionStrings.config</c> (fuera de git). Cada operación abre y cierra
    /// su conexión: el pool de MySql.Data la reutiliza, y no se comparte estado entre peticiones.
    /// </remarks>
    public class FabricaConexion
    {
        /// <summary>Nombre de la cadena de conexión en <c>connectionStrings</c>.</summary>
        public const string NombreCadena = "Atalaya";

        private readonly string _cadena;

        /// <summary>
        /// Lee la cadena de conexión de la configuración.
        /// </summary>
        /// <exception cref="ConfigurationErrorsException">Si la cadena no existe o está vacía.</exception>
        public FabricaConexion()
        {
            var entrada = ConfigurationManager.ConnectionStrings[NombreCadena];
            if (entrada == null || string.IsNullOrWhiteSpace(entrada.ConnectionString))
            {
                throw new ConfigurationErrorsException(
                    "Falta la cadena de conexión 'Atalaya'. Copie ConnectionStrings.example.config como ConnectionStrings.config y complétela.");
            }
            _cadena = entrada.ConnectionString;
        }

        /// <summary>
        /// Usa una cadena explícita (útil para pruebas o herramientas).
        /// </summary>
        /// <param name="cadena">Cadena de conexión MySQL.</param>
        public FabricaConexion(string cadena)
        {
            _cadena = cadena;
        }

        /// <summary>
        /// Devuelve una conexión ya abierta; quien la pide debe liberarla con <c>using</c>.
        /// </summary>
        public MySqlConnection Abrir()
        {
            var conexion = new MySqlConnection(_cadena);
            conexion.Open();
            return conexion;
        }
    }
}
