using System;
using System.Data;
using MySql.Data.MySqlClient;

namespace Atalaya.Datos
{
    /// <summary>
    /// Base de los repositorios: arma comandos de procedimiento almacenado con parámetros tipados.
    /// </summary>
    /// <remarks>
    /// Todo pasa por <see cref="CommandType.StoredProcedure"/> y <see cref="MySqlParameter"/>:
    /// los valores nunca se concatenan al SQL, así que no hay inyección posible desde la API.
    /// </remarks>
    public abstract class AccesoDatos
    {
        /// <summary>Fábrica de conexiones compartida por el repositorio.</summary>
        protected FabricaConexion Fabrica { get; }

        /// <summary>Crea el repositorio con su fábrica de conexiones.</summary>
        /// <param name="fabrica">Fábrica de conexiones.</param>
        protected AccesoDatos(FabricaConexion fabrica)
        {
            Fabrica = fabrica ?? throw new ArgumentNullException(nameof(fabrica));
        }

        /// <summary>
        /// Crea un comando que invoca el SP indicado sobre una conexión abierta.
        /// </summary>
        /// <param name="conexion">Conexión abierta.</param>
        /// <param name="procedimiento">Nombre del SP (constante del código, nunca dato del usuario).</param>
        protected static MySqlCommand CrearComando(MySqlConnection conexion, string procedimiento)
        {
            return new MySqlCommand(procedimiento, conexion)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 30
            };
        }

        /// <summary>Agrega un parámetro tipado; <c>null</c> se envía como <see cref="DBNull"/>.</summary>
        /// <param name="comando">Comando destino.</param>
        /// <param name="nombre">Nombre del parámetro del SP (ej. <c>p_id_usuario</c>).</param>
        /// <param name="tipo">Tipo MySQL.</param>
        /// <param name="valor">Valor.</param>
        protected static void Agregar(MySqlCommand comando, string nombre, MySqlDbType tipo, object valor)
        {
            comando.Parameters.Add(new MySqlParameter("@" + nombre, tipo) { Value = valor ?? DBNull.Value });
        }

        /// <summary>Recorta un texto al tamaño de la columna para no fallar por longitud.</summary>
        protected static string Recortar(string texto, int maximo)
        {
            if (texto == null) return null;
            return texto.Length <= maximo ? texto : texto.Substring(0, maximo);
        }
    }

    /// <summary>
    /// Lectura segura de columnas por nombre (alias del contrato), tolerante a <c>NULL</c>
    /// y a las variaciones de tipo de MySQL (TINYINT como bool, COUNT como BIGINT, SUM como DECIMAL).
    /// </summary>
    public static class LectorExtensiones
    {
        private static object Valor(IDataRecord r, string columna)
        {
            var valor = r[columna];
            return valor == DBNull.Value ? null : valor;
        }

        /// <summary>Texto o <c>null</c>.</summary>
        public static string Texto(this IDataRecord r, string columna)
        {
            return Valor(r, columna)?.ToString();
        }

        /// <summary>Entero de 32 bits (0 si es NULL).</summary>
        public static int Entero(this IDataRecord r, string columna)
        {
            var v = Valor(r, columna);
            return v == null ? 0 : Convert.ToInt32(v);
        }

        /// <summary>Entero de 32 bits o <c>null</c>.</summary>
        public static int? EnteroNulo(this IDataRecord r, string columna)
        {
            var v = Valor(r, columna);
            return v == null ? (int?)null : Convert.ToInt32(v);
        }

        /// <summary>Entero de 64 bits (0 si es NULL). Se usa para pesos: el contrato los exige enteros.</summary>
        public static long EnteroLargo(this IDataRecord r, string columna)
        {
            var v = Valor(r, columna);
            return v == null ? 0L : Convert.ToInt64(v);
        }

        /// <summary>Booleano (acepta TINYINT/bool/INT).</summary>
        public static bool Booleano(this IDataRecord r, string columna)
        {
            var v = Valor(r, columna);
            return v != null && Convert.ToInt32(v) != 0;
        }

        /// <summary>Fecha (<see cref="DateTime.MinValue"/> si es NULL).</summary>
        public static DateTime Fecha(this IDataRecord r, string columna)
        {
            var v = Valor(r, columna);
            return v == null ? DateTime.MinValue : Convert.ToDateTime(v);
        }

        /// <summary>Fecha o <c>null</c>.</summary>
        public static DateTime? FechaNula(this IDataRecord r, string columna)
        {
            var v = Valor(r, columna);
            return v == null ? (DateTime?)null : Convert.ToDateTime(v);
        }
    }
}
