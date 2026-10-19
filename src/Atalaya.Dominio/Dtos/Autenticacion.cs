using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Atalaya.Dominio.Entidades;

namespace Atalaya.Dominio.Dtos
{
    /// <summary>
    /// Cuerpo de <c>POST /api/auth/login</c>.
    /// </summary>
    public class SolicitudLogin
    {
        /// <summary>Nombre de usuario o correo electrónico.</summary>
        [Required(ErrorMessage = "Digite el usuario o el correo.")]
        [StringLength(150, ErrorMessage = "El usuario o correo no puede superar 150 caracteres.")]
        public string Login { get; set; }

        /// <summary>Clave en texto plano (viaja solo por HTTPS en producción y nunca se registra).</summary>
        [Required(ErrorMessage = "Digite la clave.")]
        [StringLength(128, ErrorMessage = "La clave no puede superar 128 caracteres.")]
        public string Clave { get; set; }
    }

    /// <summary>
    /// Respuesta exitosa del login: token y menú dinámico del usuario.
    /// </summary>
    public class RespuestaLogin
    {
        /// <summary>JWT firmado con HS256 para enviar en <c>Authorization: Bearer</c>.</summary>
        public string Token { get; set; }

        /// <summary>Momento de expiración del token (UTC).</summary>
        public DateTime ExpiraEn { get; set; }

        /// <summary>Datos básicos del usuario.</summary>
        public UsuarioResumen Usuario { get; set; }

        /// <summary>Menús activos asignados; con ellos el front arma la barra lateral.</summary>
        public List<MenuDto> Menus { get; set; }
    }

    /// <summary>
    /// Respuesta de <c>GET /api/auth/yo</c>.
    /// </summary>
    public class RespuestaYo
    {
        /// <summary>Datos básicos del usuario autenticado.</summary>
        public UsuarioResumen Usuario { get; set; }

        /// <summary>Menús activos asignados en este momento (se leen de la BD, no del token).</summary>
        public List<MenuDto> Menus { get; set; }
    }
}
