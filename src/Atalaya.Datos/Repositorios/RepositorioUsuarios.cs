using System;
using System.Collections.Generic;
using System.Data;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Excepciones;
using Atalaya.Dominio.Interfaces;
using Atalaya.Dominio.Seguridad;
using MySql.Data.MySqlClient;

namespace Atalaya.Datos.Repositorios
{
    /// <summary>
    /// Implementación MySQL de <see cref="IRepositorioUsuarios"/> sobre los SPs <c>sp_usuario_*</c>.
    /// </summary>
    public class RepositorioUsuarios : AccesoDatos, IRepositorioUsuarios
    {
        /// <summary>Crea el repositorio.</summary>
        /// <param name="fabrica">Fábrica de conexiones.</param>
        public RepositorioUsuarios(FabricaConexion fabrica) : base(fabrica) { }

        /// <inheritdoc />
        public List<UsuarioDto> Listar(string buscar)
        {
            var lista = new List<UsuarioDto>();
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_listar"))
            {
                Agregar(cmd, "p_buscar", MySqlDbType.VarChar, string.IsNullOrWhiteSpace(buscar) ? null : buscar.Trim());
                using (var r = cmd.ExecuteReader())
                {
                    while (r.Read()) lista.Add(Mapear(r));
                }
            }
            return lista;
        }

        /// <inheritdoc />
        public UsuarioDto Obtener(int idUsuario)
        {
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_obtener"))
            {
                Agregar(cmd, "p_id_usuario", MySqlDbType.Int32, idUsuario);
                using (var r = cmd.ExecuteReader())
                {
                    return r.Read() ? Mapear(r) : null;
                }
            }
        }

        /// <inheritdoc />
        public UsuarioParaLogin ObtenerParaLogin(string login)
        {
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_obtener_para_login"))
            {
                Agregar(cmd, "p_login", MySqlDbType.VarChar, login);
                using (var r = cmd.ExecuteReader())
                {
                    if (!r.Read()) return null;
                    return new UsuarioParaLogin
                    {
                        Id = r.Entero("id_usuario"),
                        Nombre = r.Texto("nombre"),
                        Usuario = r.Texto("usuario"),
                        Correo = r.Texto("correo"),
                        HashClave = r.Texto("hash_clave"),
                        SalClave = r.Texto("sal_clave"),
                        Iteraciones = r.Entero("iteraciones"),
                        Activo = r.Booleano("estado"),
                        IntentosFallidos = r.Entero("intentos_fallidos"),
                        BloqueadoHasta = r.FechaNula("bloqueado_hasta")
                    };
                }
            }
        }

        /// <inheritdoc />
        public ResultadoIntentoLogin RegistrarLogin(int idUsuario, bool exitoso, string ip)
        {
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_registrar_login"))
            {
                Agregar(cmd, "p_id_usuario", MySqlDbType.Int32, idUsuario);
                Agregar(cmd, "p_exitoso", MySqlDbType.Byte, exitoso ? (sbyte)1 : (sbyte)0);
                Agregar(cmd, "p_ip", MySqlDbType.VarChar, Recortar(ip, 45));
                using (var r = cmd.ExecuteReader())
                {
                    if (!r.Read()) return new ResultadoIntentoLogin();
                    return new ResultadoIntentoLogin
                    {
                        IntentosFallidos = r.Entero("intentos_fallidos"),
                        BloqueadoHasta = r.FechaNula("bloqueado_hasta")
                    };
                }
            }
        }

        /// <inheritdoc />
        /// <remarks>
        /// La unicidad la garantiza la BD (índices UNIQUE + SIGNAL en el SP). Aquí solo se traduce el error
        /// técnico de MySQL a un <see cref="ConflictoException"/> con el código del contrato.
        /// </remarks>
        public int Crear(string nombre, string usuario, string correo, ClaveDerivada clave, bool activo, int? creadoPor)
        {
            try
            {
                using (var cn = Fabrica.Abrir())
                using (var cmd = CrearComando(cn, "sp_usuario_crear"))
                {
                    Agregar(cmd, "p_nombre", MySqlDbType.VarChar, nombre);
                    Agregar(cmd, "p_usuario", MySqlDbType.VarChar, usuario);
                    Agregar(cmd, "p_correo", MySqlDbType.VarChar, correo);
                    Agregar(cmd, "p_hash_clave", MySqlDbType.VarChar, clave.Hash);
                    Agregar(cmd, "p_sal_clave", MySqlDbType.VarChar, clave.Sal);
                    Agregar(cmd, "p_iteraciones", MySqlDbType.Int32, clave.Iteraciones);
                    Agregar(cmd, "p_estado", MySqlDbType.Byte, activo ? (sbyte)1 : (sbyte)0);
                    Agregar(cmd, "p_creado_por", MySqlDbType.Int32, creadoPor);
                    using (var r = cmd.ExecuteReader())
                    {
                        if (!r.Read()) throw new InvalidOperationException("sp_usuario_crear no devolvió id_usuario.");
                        return r.Entero("id_usuario");
                    }
                }
            }
            catch (MySqlException ex)
            {
                var traducida = TraducirDuplicado(ex);
                if (traducida != null) throw traducida;
                throw;
            }
        }

        /// <inheritdoc />
        public int CambiarEstado(int idUsuario, bool activo)
        {
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_cambiar_estado"))
            {
                Agregar(cmd, "p_id_usuario", MySqlDbType.Int32, idUsuario);
                Agregar(cmd, "p_estado", MySqlDbType.Byte, activo ? (sbyte)1 : (sbyte)0);
                using (var r = cmd.ExecuteReader())
                {
                    return r.Read() ? r.Entero("filas_afectadas") : 0;
                }
            }
        }

        /// <inheritdoc />
        public bool TieneMenu(int idUsuario, string codigoMenu)
        {
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_tiene_menu"))
            {
                Agregar(cmd, "p_id_usuario", MySqlDbType.Int32, idUsuario);
                Agregar(cmd, "p_codigo_menu", MySqlDbType.VarChar, codigoMenu);
                using (var r = cmd.ExecuteReader())
                {
                    return r.Read() && r.Booleano("autorizado");
                }
            }
        }

        private static UsuarioDto Mapear(IDataRecord r)
        {
            return new UsuarioDto
            {
                Id = r.Entero("id_usuario"),
                Nombre = r.Texto("nombre"),
                Usuario = r.Texto("usuario"),
                Correo = r.Texto("correo"),
                Activo = r.Booleano("estado"),
                UltimoAcceso = r.FechaNula("ultimo_acceso"),
                FechaCreacion = r.Fecha("fecha_creacion"),
                TotalMenus = r.Entero("total_menus")
            };
        }

        /// <summary>
        /// Convierte el SIGNAL del SP (o una violación de UNIQUE por concurrencia) en un 409 del contrato.
        /// </summary>
        private static ConflictoException TraducirDuplicado(MySqlException ex)
        {
            var mensaje = ex.Message ?? string.Empty;
            if (mensaje.IndexOf("USUARIO_DUPLICADO", StringComparison.OrdinalIgnoreCase) >= 0)
                return new ConflictoException("USUARIO_DUPLICADO", "Ya existe un usuario con ese nombre de usuario.");
            if (mensaje.IndexOf("CORREO_DUPLICADO", StringComparison.OrdinalIgnoreCase) >= 0)
                return new ConflictoException("CORREO_DUPLICADO", "Ya existe un usuario con ese correo.");

            // 1062 = ER_DUP_ENTRY: dos altas simultáneas pueden pasar la validación del SP y chocar en el índice.
            if (ex.Number == 1062)
            {
                return mensaje.IndexOf("correo", StringComparison.OrdinalIgnoreCase) >= 0
                    ? new ConflictoException("CORREO_DUPLICADO", "Ya existe un usuario con ese correo.")
                    : new ConflictoException("USUARIO_DUPLICADO", "Ya existe un usuario con ese nombre de usuario.");
            }
            return null;
        }
    }
}
