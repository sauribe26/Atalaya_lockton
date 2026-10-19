using System.Collections.Generic;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Interfaces;
using MySql.Data.MySqlClient;

namespace Atalaya.Datos.Repositorios
{
    /// <summary>
    /// Implementación MySQL de <see cref="IRepositorioBitacora"/>.
    /// </summary>
    public class RepositorioBitacora : AccesoDatos, IRepositorioBitacora
    {
        /// <summary>Crea el repositorio.</summary>
        /// <param name="fabrica">Fábrica de conexiones.</param>
        public RepositorioBitacora(FabricaConexion fabrica) : base(fabrica) { }

        /// <inheritdoc />
        public void Registrar(NuevoEventoBitacora evento)
        {
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_bitacora_registrar"))
            {
                Agregar(cmd, "p_id_usuario", MySqlDbType.Int32, evento.IdUsuario);
                Agregar(cmd, "p_usuario_texto", MySqlDbType.VarChar, Recortar(evento.UsuarioTexto, 50));
                Agregar(cmd, "p_evento", MySqlDbType.VarChar, Recortar(evento.Evento, 30));
                Agregar(cmd, "p_recurso", MySqlDbType.VarChar, Recortar(evento.Recurso, 150));
                Agregar(cmd, "p_ip", MySqlDbType.VarChar, Recortar(evento.Ip, 45));
                Agregar(cmd, "p_detalle", MySqlDbType.VarChar, Recortar(evento.Detalle, 255));
                cmd.ExecuteNonQuery();
            }
        }

        /// <inheritdoc />
        public List<EventoBitacora> Listar(string evento, int limite)
        {
            var lista = new List<EventoBitacora>();
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_bitacora_listar"))
            {
                Agregar(cmd, "p_evento", MySqlDbType.VarChar, string.IsNullOrWhiteSpace(evento) ? null : evento.Trim().ToUpperInvariant());
                Agregar(cmd, "p_limite", MySqlDbType.Int32, limite);
                using (var r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        lista.Add(new EventoBitacora
                        {
                            Id = r.EnteroLargo("id_bitacora"),
                            Fecha = r.Fecha("fecha"),
                            IdUsuario = r.EnteroNulo("id_usuario"),
                            Usuario = r.Texto("usuario_texto"),
                            Evento = r.Texto("evento"),
                            Recurso = r.Texto("recurso"),
                            Ip = r.Texto("ip"),
                            Detalle = r.Texto("detalle")
                        });
                    }
                }
            }
            return lista;
        }
    }
}
