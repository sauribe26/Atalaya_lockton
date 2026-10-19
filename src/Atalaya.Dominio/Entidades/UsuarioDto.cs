using System;

namespace Atalaya.Dominio.Entidades
{
    /// <summary>
    /// Usuario tal como lo expone la API (modelo <c>Usuario</c> del contrato). Nunca incluye hash ni sal.
    /// </summary>
    public class UsuarioDto
    {
        /// <summary>Identificador (<c>id_usuario</c>).</summary>
        public int Id { get; set; }

        /// <summary>Nombre completo.</summary>
        public string Nombre { get; set; }

        /// <summary>Nombre de usuario para iniciar sesión.</summary>
        public string Usuario { get; set; }

        /// <summary>Correo electrónico (también sirve para iniciar sesión).</summary>
        public string Correo { get; set; }

        /// <summary>Si el usuario está activo (<c>estado = 1</c>).</summary>
        public bool Activo { get; set; }

        /// <summary>Último inicio de sesión exitoso; <c>null</c> si nunca ha entrado.</summary>
        public DateTime? UltimoAcceso { get; set; }

        /// <summary>Fecha de creación del registro.</summary>
        public DateTime FechaCreacion { get; set; }

        /// <summary>Cantidad de menús asignados.</summary>
        public int TotalMenus { get; set; }
    }

    /// <summary>
    /// Datos mínimos del usuario autenticado que viajan en el login y en <c>/api/auth/yo</c>.
    /// </summary>
    public class UsuarioResumen
    {
        /// <summary>Identificador del usuario.</summary>
        public int Id { get; set; }

        /// <summary>Nombre completo.</summary>
        public string Nombre { get; set; }

        /// <summary>Nombre de usuario.</summary>
        public string Usuario { get; set; }

        /// <summary>Correo electrónico.</summary>
        public string Correo { get; set; }
    }
}
