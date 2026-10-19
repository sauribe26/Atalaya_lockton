using System;

namespace Atalaya.Dominio.Entidades
{
    /// <summary>
    /// Registro de la bitácora de accesos (modelo <c>Evento</c> del contrato).
    /// </summary>
    public class EventoBitacora
    {
        /// <summary>Identificador (<c>id_bitacora</c>).</summary>
        public long Id { get; set; }

        /// <summary>Fecha y hora del evento (hora del servidor de BD).</summary>
        public DateTime Fecha { get; set; }

        /// <summary>Usuario involucrado; <c>null</c> si el login no correspondía a ningún usuario.</summary>
        public int? IdUsuario { get; set; }

        /// <summary>Texto del usuario tal como se digitó o se resolvió.</summary>
        public string Usuario { get; set; }

        /// <summary>Código del evento (ver <see cref="Seguridad.EventosBitacora"/>).</summary>
        public string Evento { get; set; }

        /// <summary>Recurso afectado (ruta de la API o menú).</summary>
        public string Recurso { get; set; }

        /// <summary>IP del cliente.</summary>
        public string Ip { get; set; }

        /// <summary>Detalle libre.</summary>
        public string Detalle { get; set; }
    }

    /// <summary>
    /// Datos para registrar un evento en la bitácora.
    /// </summary>
    public class NuevoEventoBitacora
    {
        /// <summary>Usuario involucrado, si se conoce.</summary>
        public int? IdUsuario { get; set; }

        /// <summary>Texto de usuario (se recorta a 50 caracteres).</summary>
        public string UsuarioTexto { get; set; }

        /// <summary>Código del evento.</summary>
        public string Evento { get; set; }

        /// <summary>Recurso afectado (se recorta a 150 caracteres).</summary>
        public string Recurso { get; set; }

        /// <summary>IP del cliente.</summary>
        public string Ip { get; set; }

        /// <summary>Detalle (se recorta a 255 caracteres).</summary>
        public string Detalle { get; set; }
    }
}
