namespace Atalaya.Dominio.Seguridad
{
    /// <summary>
    /// Códigos de evento que se guardan en <c>bitacora_acceso.evento</c>.
    /// </summary>
    /// <remarks>Centralizados como constantes para que el tablero y los filtros no dependan de textos sueltos.</remarks>
    public static class EventosBitacora
    {
        /// <summary>Inicio de sesión exitoso.</summary>
        public const string LoginOk = "LOGIN_OK";
        /// <summary>Credenciales inválidas o usuario inactivo.</summary>
        public const string LoginFallido = "LOGIN_FALLIDO";
        /// <summary>Intento sobre una cuenta bloqueada o intento que provocó el bloqueo.</summary>
        public const string LoginBloqueado = "LOGIN_BLOQUEADO";
        /// <summary>Petición rechazada por falta de permiso sobre un menú.</summary>
        public const string AccesoDenegado = "ACCESO_DENEGADO";
        /// <summary>Alta de usuario.</summary>
        public const string UsuarioCreado = "USUARIO_CREADO";
        /// <summary>Activación o inactivación de usuario.</summary>
        public const string UsuarioEstado = "USUARIO_ESTADO";
        /// <summary>Cambio en la asignación de menús de un usuario.</summary>
        public const string MenusActualizados = "MENUS_ACTUALIZADOS";
    }

    /// <summary>
    /// Códigos funcionales de los menús semilla, usados en <c>[RequiereMenu]</c>.
    /// </summary>
    public static class CodigosMenu
    {
        /// <summary>Tablero de indicadores.</summary>
        public const string Tablero = "TABLERO";
        /// <summary>Gestión de usuarios.</summary>
        public const string Usuarios = "USUARIOS";
        /// <summary>Asignación de menús a usuarios.</summary>
        public const string Asignacion = "ASIGNACION";
        /// <summary>Bitácora de accesos.</summary>
        public const string Auditoria = "AUDITORIA";
        /// <summary>Clientes (negocio demo).</summary>
        public const string Clientes = "CLIENTES";
        /// <summary>Pólizas (negocio demo).</summary>
        public const string Polizas = "POLIZAS";
        /// <summary>Siniestros (negocio demo).</summary>
        public const string Siniestros = "SINIESTROS";
    }
}
