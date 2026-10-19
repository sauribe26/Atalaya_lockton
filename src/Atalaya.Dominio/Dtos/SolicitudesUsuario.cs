using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Atalaya.Dominio.Entidades;

namespace Atalaya.Dominio.Dtos
{
    /// <summary>
    /// Cuerpo de <c>POST /api/users</c>.
    /// </summary>
    /// <remarks>
    /// Las reglas viven aquí como DataAnnotations para que Web API las evalúe antes de entrar a la acción
    /// y el error 400 traiga el detalle por campo. La BD vuelve a proteger la unicidad (409).
    /// </remarks>
    public class SolicitudCrearUsuario
    {
        /// <summary>Nombre completo (3 a 120 caracteres).</summary>
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(120, MinimumLength = 3, ErrorMessage = "El nombre debe tener entre 3 y 120 caracteres.")]
        public string Nombre { get; set; }

        /// <summary>Usuario de acceso: 3 a 50 caracteres, solo minúsculas, números, punto, guion y guion bajo.</summary>
        [Required(ErrorMessage = "El usuario es obligatorio.")]
        [StringLength(50, MinimumLength = 3, ErrorMessage = "El usuario debe tener entre 3 y 50 caracteres.")]
        [RegularExpression("^[a-z0-9._-]+$", ErrorMessage = "El usuario solo admite minúsculas, números, punto, guion y guion bajo.")]
        public string Usuario { get; set; }

        /// <summary>Correo electrónico válido (máximo 150).</summary>
        [Required(ErrorMessage = "El correo es obligatorio.")]
        [StringLength(150, ErrorMessage = "El correo no puede superar 150 caracteres.")]
        [EmailAddress(ErrorMessage = "El correo no tiene un formato válido.")]
        public string Correo { get; set; }

        /// <summary>Clave inicial: mínimo 8 caracteres con mayúscula, minúscula, número y símbolo.</summary>
        [Required(ErrorMessage = "La clave es obligatoria.")]
        [StringLength(128, MinimumLength = 8, ErrorMessage = "La clave debe tener entre 8 y 128 caracteres.")]
        [RegularExpression(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$",
            ErrorMessage = "La clave debe incluir mayúscula, minúscula, número y símbolo.")]
        public string Clave { get; set; }

        /// <summary>Si nace activo. Por defecto <c>true</c> cuando no se envía.</summary>
        public bool Activo { get; set; } = true;
    }

    /// <summary>
    /// Cuerpo de <c>PATCH /api/users/{id}/estado</c>.
    /// </summary>
    public class SolicitudCambiarEstado
    {
        /// <summary>Nuevo estado: <c>true</c> activa, <c>false</c> inactiva.</summary>
        [Required(ErrorMessage = "Indique si el usuario queda activo.")]
        public bool? Activo { get; set; }
    }

    /// <summary>
    /// Cuerpo de <c>PUT /api/users/{id}/menus</c>: la lista completa de menús que debe quedar asignada.
    /// </summary>
    /// <remarks>Se reemplaza el conjunto completo (PUT idempotente) en vez de agregar/quitar uno a uno.</remarks>
    public class SolicitudAsignarMenus
    {
        /// <summary>Ids de menú; lista vacía retira todos.</summary>
        [Required(ErrorMessage = "Envíe la lista menuIds (puede ser vacía).")]
        public List<int> MenuIds { get; set; }
    }

    /// <summary>
    /// Resultado de reemplazar la asignación de menús.
    /// </summary>
    public class ResultadoAsignacion
    {
        /// <summary>Menús agregados.</summary>
        public int Agregados { get; set; }

        /// <summary>Menús retirados.</summary>
        public int Retirados { get; set; }

        /// <summary>Asignación resultante.</summary>
        public List<MenuDto> Menus { get; set; }
    }

    /// <summary>
    /// Respuesta de <c>GET /api/salud</c>.
    /// </summary>
    public class EstadoSalud
    {
        /// <summary><c>ok</c> o <c>degradado</c>.</summary>
        public string Estado { get; set; }

        /// <summary><c>ok</c> o <c>error</c> según si la BD respondió.</summary>
        public string BaseDatos { get; set; }

        /// <summary>Hora del servidor web (ISO 8601).</summary>
        public System.DateTime Hora { get; set; }
    }
}
