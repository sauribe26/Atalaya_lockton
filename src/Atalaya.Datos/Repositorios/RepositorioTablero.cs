using Atalaya.Dominio.Dtos;
using Atalaya.Dominio.Interfaces;

namespace Atalaya.Datos.Repositorios
{
    /// <summary>
    /// Implementación MySQL de <see cref="IRepositorioTablero"/>.
    /// </summary>
    /// <remarks>
    /// <c>sp_tablero_kpis</c> devuelve cuatro resultsets en un solo viaje a la BD; se recorren con
    /// <c>NextResult()</c> en el orden del contrato.
    /// </remarks>
    public class RepositorioTablero : AccesoDatos, IRepositorioTablero
    {
        /// <summary>Crea el repositorio.</summary>
        /// <param name="fabrica">Fábrica de conexiones.</param>
        public RepositorioTablero(FabricaConexion fabrica) : base(fabrica) { }

        /// <inheritdoc />
        public Tablero Obtener()
        {
            var tablero = new Tablero { Kpis = new Kpis() };
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_tablero_kpis"))
            using (var r = cmd.ExecuteReader())
            {
                // 1) KPIs
                if (r.Read())
                {
                    tablero.Kpis = new Kpis
                    {
                        UsuariosTotal = r.Entero("usuarios_total"),
                        UsuariosActivos = r.Entero("usuarios_activos"),
                        MenusActivos = r.Entero("menus_activos"),
                        AsignacionesTotal = r.Entero("asignaciones_total"),
                        LoginsHoy = r.Entero("logins_hoy"),
                        Denegados7d = r.Entero("denegados_7d"),
                        Fallidos7d = r.Entero("fallidos_7d"),
                        BloqueadosAhora = r.Entero("bloqueados_ahora")
                    };
                }

                // 2) Serie de 14 días
                if (r.NextResult())
                {
                    while (r.Read())
                    {
                        tablero.Serie.Add(new PuntoSerie
                        {
                            Dia = r.Fecha("dia"),
                            LoginsOk = r.Entero("logins_ok"),
                            LoginsFallidos = r.Entero("logins_fallidos"),
                            AccesosDenegados = r.Entero("accesos_denegados")
                        });
                    }
                }

                // 3) Uso por menú
                if (r.NextResult())
                {
                    while (r.Read())
                    {
                        tablero.UsoMenus.Add(new UsoMenu
                        {
                            Codigo = r.Texto("codigo"),
                            Nombre = r.Texto("nombre"),
                            TotalUsuarios = r.Entero("total_usuarios")
                        });
                    }
                }

                // 4) Matriz usuario × menú
                if (r.NextResult())
                {
                    while (r.Read())
                    {
                        tablero.Matriz.Add(new CeldaMatriz
                        {
                            IdUsuario = r.Entero("id_usuario"),
                            Usuario = r.Texto("usuario"),
                            Codigo = r.Texto("codigo")
                        });
                    }
                }
            }
            return tablero;
        }
    }
}
