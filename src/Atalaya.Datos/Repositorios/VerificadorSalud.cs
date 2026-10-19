using System;
using System.Diagnostics;
using Atalaya.Dominio.Interfaces;

namespace Atalaya.Datos.Repositorios
{
    /// <summary>
    /// Comprueba que la base de datos responde, sin ejecutar SQL: abre una conexión y hace <c>Ping</c>.
    /// </summary>
    public class VerificadorSalud : IVerificadorSalud
    {
        private readonly Func<FabricaConexion> _crearFabrica;

        /// <summary>Crea el verificador.</summary>
        /// <param name="crearFabrica">Crea la fábrica al momento de verificar (si falta la cadena, se reporta como BD caída en vez de romper).</param>
        public VerificadorSalud(Func<FabricaConexion> crearFabrica)
        {
            _crearFabrica = crearFabrica;
        }

        /// <inheritdoc />
        public bool BaseDatosDisponible()
        {
            try
            {
                using (var cn = _crearFabrica().Abrir())
                {
                    return cn.Ping();
                }
            }
            catch (Exception ex)
            {
                // Se registra el tipo, no el mensaje completo, para no dejar datos de conexión en el log.
                Trace.TraceWarning("Salud: la BD no respondió ({0}).", ex.GetType().Name);
                return false;
            }
        }
    }
}
