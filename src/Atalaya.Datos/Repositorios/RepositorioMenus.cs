using System.Collections.Generic;
using System.Data;
using System.Linq;
using Atalaya.Dominio.Dtos;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Interfaces;
using MySql.Data.MySqlClient;

namespace Atalaya.Datos.Repositorios
{
    /// <summary>
    /// Implementación MySQL de <see cref="IRepositorioMenus"/>.
    /// </summary>
    public class RepositorioMenus : AccesoDatos, IRepositorioMenus
    {
        /// <summary>Crea el repositorio.</summary>
        /// <param name="fabrica">Fábrica de conexiones.</param>
        public RepositorioMenus(FabricaConexion fabrica) : base(fabrica) { }

        /// <inheritdoc />
        public List<MenuDto> Listar(bool soloActivos)
        {
            var lista = new List<MenuDto>();
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_menu_listar"))
            {
                Agregar(cmd, "p_solo_activos", MySqlDbType.Byte, soloActivos ? (sbyte)1 : (sbyte)0);
                using (var r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var m = MapearBase(r);
                        m.TotalUsuarios = r.Entero("total_usuarios");
                        lista.Add(m);
                    }
                }
            }
            return lista;
        }

        /// <inheritdoc />
        public List<MenuDto> ListarDeUsuario(int idUsuario)
        {
            var lista = new List<MenuDto>();
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_menus_listar"))
            {
                Agregar(cmd, "p_id_usuario", MySqlDbType.Int32, idUsuario);
                using (var r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var m = MapearBase(r);
                        m.FechaAsignacion = r.FechaNula("fecha_asignacion");
                        lista.Add(m);
                    }
                }
            }
            return lista;
        }

        /// <inheritdoc />
        /// <remarks>
        /// Los ids viajan como CSV porque MySQL no tiene parámetros de tipo tabla; como son <c>int</c>
        /// ya validados, el CSV solo puede contener dígitos y comas.
        /// </remarks>
        public ResultadoAsignacion Reemplazar(int idUsuario, IEnumerable<int> idsMenu, int? asignadoPor)
        {
            var csv = string.Join(",", (idsMenu ?? Enumerable.Empty<int>()).Distinct());
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_usuario_menus_reemplazar"))
            {
                Agregar(cmd, "p_id_usuario", MySqlDbType.Int32, idUsuario);
                Agregar(cmd, "p_ids_menu", MySqlDbType.VarChar, csv);
                Agregar(cmd, "p_asignado_por", MySqlDbType.Int32, asignadoPor);
                using (var r = cmd.ExecuteReader())
                {
                    var resultado = new ResultadoAsignacion();
                    if (r.Read())
                    {
                        resultado.Agregados = r.Entero("agregados");
                        resultado.Retirados = r.Entero("retirados");
                    }
                    return resultado;
                }
            }
        }

        private static MenuDto MapearBase(IDataRecord r)
        {
            return new MenuDto
            {
                Id = r.Entero("id_menu"),
                Codigo = r.Texto("codigo"),
                Nombre = r.Texto("nombre"),
                Descripcion = r.Texto("descripcion"),
                Ruta = r.Texto("ruta"),
                Icono = r.Texto("icono"),
                Grupo = r.Texto("grupo"),
                Orden = r.Entero("orden")
            };
        }
    }
}
