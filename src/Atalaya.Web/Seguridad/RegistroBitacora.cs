using System;
using System.Diagnostics;
using System.Net.Http;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Interfaces;

namespace Atalaya.Web.Seguridad
{
    /// <summary>
    /// Escribe eventos en la bitácora sin poner en riesgo la petición.
    /// </summary>
    /// <remarks>
    /// Si la bitácora falla (BD lenta, columna llena), se registra en el log del servidor y la petición
    /// sigue: es preferible no auditar un evento que dejar a un usuario sin poder iniciar sesión.
    /// </remarks>
    public static class RegistroBitacora
    {
        /// <summary>
        /// Registra un evento con la IP y el recurso de la petición.
        /// </summary>
        /// <param name="repositorio">Repositorio de bitácora.</param>
        /// <param name="request">Petición actual (de aquí salen IP y recurso).</param>
        /// <param name="evento">Código del evento.</param>
        /// <param name="idUsuario">Usuario involucrado, si se conoce.</param>
        /// <param name="usuarioTexto">Texto del usuario.</param>
        /// <param name="detalle">Detalle libre (nunca claves ni tokens).</param>
        public static void Registrar(IRepositorioBitacora repositorio, HttpRequestMessage request, string evento,
            int? idUsuario, string usuarioTexto, string detalle)
        {
            try
            {
                repositorio.Registrar(new NuevoEventoBitacora
                {
                    IdUsuario = idUsuario,
                    UsuarioTexto = usuarioTexto,
                    Evento = evento,
                    Recurso = ContextoPeticion.Recurso(request),
                    Ip = ContextoPeticion.Ip(request),
                    Detalle = detalle
                });
            }
            catch (Exception ex)
            {
                Trace.TraceError("No se pudo escribir en la bitácora el evento {0}: {1}", evento, ex.GetType().Name);
            }
        }
    }
}
