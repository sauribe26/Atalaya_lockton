using System;

namespace Atalaya.Dominio.Entidades
{
    /// <summary>
    /// Datos internos que necesita el login (incluye hash y sal). Nunca se serializa hacia el cliente.
    /// </summary>
    public class UsuarioParaLogin
    {
        /// <summary>Identificador del usuario.</summary>
        public int Id { get; set; }

        /// <summary>Nombre completo.</summary>
        public string Nombre { get; set; }

        /// <summary>Nombre de usuario.</summary>
        public string Usuario { get; set; }

        /// <summary>Correo electrónico.</summary>
        public string Correo { get; set; }

        /// <summary>Hash PBKDF2 en Base64.</summary>
        public string HashClave { get; set; }

        /// <summary>Sal en Base64.</summary>
        public string SalClave { get; set; }

        /// <summary>Iteraciones con las que se generó el hash.</summary>
        public int Iteraciones { get; set; }

        /// <summary>Si el usuario está activo.</summary>
        public bool Activo { get; set; }

        /// <summary>Intentos fallidos consecutivos.</summary>
        public int IntentosFallidos { get; set; }

        /// <summary>Hasta cuándo está bloqueada la cuenta; <c>null</c> si no lo está.</summary>
        public DateTime? BloqueadoHasta { get; set; }
    }

    /// <summary>
    /// Estado de bloqueo que devuelve <c>sp_usuario_registrar_login</c> después de registrar un intento.
    /// </summary>
    public class ResultadoIntentoLogin
    {
        /// <summary>Intentos fallidos acumulados tras este intento.</summary>
        public int IntentosFallidos { get; set; }

        /// <summary>Fin del bloqueo si este intento lo provocó (o ya existía).</summary>
        public DateTime? BloqueadoHasta { get; set; }
    }
}
