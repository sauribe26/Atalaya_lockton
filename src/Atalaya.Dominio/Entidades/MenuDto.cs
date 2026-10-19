using System;
using Newtonsoft.Json;

namespace Atalaya.Dominio.Entidades
{
    /// <summary>
    /// Opción de menú (modelo <c>Menu</c> del contrato). El front arma la barra lateral solo con estos registros.
    /// </summary>
    public class MenuDto
    {
        /// <summary>Identificador (<c>id_menu</c>).</summary>
        public int Id { get; set; }

        /// <summary>Código funcional estable (ej. <c>USUARIOS</c>); es lo que valida el backend.</summary>
        public string Codigo { get; set; }

        /// <summary>Nombre visible.</summary>
        public string Nombre { get; set; }

        /// <summary>Descripción corta.</summary>
        public string Descripcion { get; set; }

        /// <summary>Ruta hash del front (ej. <c>#/usuarios</c>).</summary>
        public string Ruta { get; set; }

        /// <summary>Ícono de Bootstrap Icons sin el prefijo <c>bi-</c>.</summary>
        public string Icono { get; set; }

        /// <summary>Grupo de la barra lateral (Gestión, Operación, Control).</summary>
        public string Grupo { get; set; }

        /// <summary>Orden dentro de la barra lateral.</summary>
        public int Orden { get; set; }

        /// <summary>Usuarios que tienen el menú (solo en el catálogo; se omite en el JSON si no aplica).</summary>
        [JsonProperty(NullValueHandling = NullValueHandling.Ignore)]
        public int? TotalUsuarios { get; set; }

        /// <summary>Fecha en que se asignó al usuario (solo en menús de un usuario; se omite si no aplica).</summary>
        [JsonProperty(NullValueHandling = NullValueHandling.Ignore)]
        public DateTime? FechaAsignacion { get; set; }
    }
}
