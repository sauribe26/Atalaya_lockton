using System.Collections.Generic;

namespace Atalaya.Dominio.Dtos
{
    /// <summary>
    /// Formato único de error de la API.
    /// </summary>
    /// <remarks>
    /// Un solo formato permite que el front maneje cualquier error con el mismo código.
    /// <c>traza</c> es un identificador corto que también queda en el log del servidor: con él se ubica
    /// el detalle técnico sin exponer el stack trace al cliente.
    /// </remarks>
    public class ErrorApi
    {
        /// <summary>Código HTTP (repetido en el cuerpo para comodidad del cliente).</summary>
        public int Estado { get; set; }

        /// <summary>Código funcional en mayúsculas (ej. <c>ACCESO_DENEGADO</c>).</summary>
        public string Codigo { get; set; }

        /// <summary>Mensaje legible para el usuario final.</summary>
        public string Mensaje { get; set; }

        /// <summary>En errores de validación (400): campo → mensaje. En los demás casos <c>null</c>.</summary>
        public Dictionary<string, string> Detalles { get; set; }

        /// <summary>Identificador de correlación con el log del servidor.</summary>
        public string Traza { get; set; }
    }
}
