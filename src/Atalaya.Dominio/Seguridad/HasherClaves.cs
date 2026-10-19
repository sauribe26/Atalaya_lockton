using System;
using System.Security.Cryptography;

namespace Atalaya.Dominio.Seguridad
{
    /// <summary>
    /// Resultado de derivar una clave: lo que se guarda en la tabla <c>usuario</c>.
    /// </summary>
    public sealed class ClaveDerivada
    {
        /// <summary>Hash PBKDF2 de 32 bytes en Base64 (columna <c>hash_clave</c>).</summary>
        public string Hash { get; set; }

        /// <summary>Sal aleatoria de 16 bytes en Base64 (columna <c>sal_clave</c>).</summary>
        public string Sal { get; set; }

        /// <summary>Iteraciones usadas; se guardan por usuario para poder subirlas sin invalidar claves viejas.</summary>
        public int Iteraciones { get; set; }
    }

    /// <summary>
    /// Deriva y verifica claves con PBKDF2-HMAC-SHA256.
    /// </summary>
    /// <remarks>
    /// Por qué PBKDF2 y no un SHA-256 simple: un hash rápido se puede atacar por fuerza bruta a miles de
    /// millones de intentos por segundo; PBKDF2 con 100.000 iteraciones hace que cada intento cueste
    /// trabajo real. La sal aleatoria por usuario impide usar tablas precalculadas y que dos usuarios
    /// con la misma clave tengan el mismo hash. Es compatible con el script semilla de Node
    /// (<c>crypto.pbkdf2Sync(clave, sal, 100000, 32, 'sha256')</c>) porque ambos usan UTF-8 y los mismos parámetros.
    /// </remarks>
    public static class HasherClaves
    {
        /// <summary>Iteraciones por defecto para claves nuevas (contrato: 100000).</summary>
        public const int IteracionesPorDefecto = 100000;

        /// <summary>Tamaño de la sal en bytes.</summary>
        public const int TamanoSal = 16;

        /// <summary>Tamaño del hash derivado en bytes.</summary>
        public const int TamanoHash = 32;

        /// <summary>
        /// Genera una sal nueva y deriva el hash de la clave.
        /// </summary>
        /// <param name="clave">Clave en texto plano (nunca se guarda ni se registra).</param>
        /// <param name="iteraciones">Iteraciones de PBKDF2; por defecto 100000.</param>
        /// <returns>Hash, sal e iteraciones listos para persistir.</returns>
        public static ClaveDerivada Derivar(string clave, int iteraciones = IteracionesPorDefecto)
        {
            if (clave == null) throw new ArgumentNullException(nameof(clave));

            var sal = new byte[TamanoSal];
            using (var rng = new RNGCryptoServiceProvider())
            {
                rng.GetBytes(sal);
            }

            return new ClaveDerivada
            {
                Hash = Convert.ToBase64String(Calcular(clave, sal, iteraciones)),
                Sal = Convert.ToBase64String(sal),
                Iteraciones = iteraciones
            };
        }

        /// <summary>
        /// Verifica una clave contra el hash y la sal guardados.
        /// </summary>
        /// <param name="clave">Clave digitada por el usuario.</param>
        /// <param name="hashBase64">Valor de <c>hash_clave</c>.</param>
        /// <param name="salBase64">Valor de <c>sal_clave</c>.</param>
        /// <param name="iteraciones">Valor de <c>iteraciones</c> del usuario.</param>
        /// <returns><c>true</c> si la clave coincide.</returns>
        /// <remarks>
        /// La comparación se hace en tiempo constante: si se cortara en el primer byte distinto,
        /// el tiempo de respuesta revelaría cuántos bytes acertó un atacante.
        /// Si los datos guardados están corruptos (Base64 inválido) se responde <c>false</c> en lugar de fallar.
        /// </remarks>
        public static bool Verificar(string clave, string hashBase64, string salBase64, int iteraciones)
        {
            if (clave == null || string.IsNullOrEmpty(hashBase64) || string.IsNullOrEmpty(salBase64) || iteraciones <= 0)
                return false;

            byte[] esperado;
            byte[] sal;
            try
            {
                esperado = Convert.FromBase64String(hashBase64);
                sal = Convert.FromBase64String(salBase64);
            }
            catch (FormatException)
            {
                return false;
            }

            var calculado = Calcular(clave, sal, iteraciones, esperado.Length);
            return SonIguales(esperado, calculado);
        }

        /// <summary>
        /// Ejecuta una derivación descartable con el mismo costo que una verificación real.
        /// </summary>
        /// <remarks>
        /// Se usa cuando el usuario no existe: así la respuesta tarda lo mismo que con una clave
        /// equivocada y no se puede averiguar qué usuarios existen midiendo tiempos.
        /// </remarks>
        public static void SimularVerificacion(string clave)
        {
            Calcular(clave ?? string.Empty, new byte[TamanoSal], IteracionesPorDefecto);
        }

        private static byte[] Calcular(string clave, byte[] sal, int iteraciones, int longitud = TamanoHash)
        {
            // El constructor con string codifica la clave en UTF-8, igual que el seed en Node.
            using (var pbkdf2 = new Rfc2898DeriveBytes(clave, sal, iteraciones, HashAlgorithmName.SHA256))
            {
                return pbkdf2.GetBytes(longitud);
            }
        }

        private static bool SonIguales(byte[] a, byte[] b)
        {
            // XOR acumulado: recorre siempre todos los bytes, sin salir antes.
            var diferencia = (uint)a.Length ^ (uint)b.Length;
            for (var i = 0; i < a.Length && i < b.Length; i++)
            {
                diferencia |= (uint)(a[i] ^ b[i]);
            }
            return diferencia == 0;
        }
    }
}
