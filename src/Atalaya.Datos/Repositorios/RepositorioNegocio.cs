using System.Collections.Generic;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Interfaces;

namespace Atalaya.Datos.Repositorios
{
    /// <summary>
    /// Implementación MySQL de <see cref="IRepositorioNegocio"/> (datos demo del broker).
    /// </summary>
    public class RepositorioNegocio : AccesoDatos, IRepositorioNegocio
    {
        /// <summary>Crea el repositorio.</summary>
        /// <param name="fabrica">Fábrica de conexiones.</param>
        public RepositorioNegocio(FabricaConexion fabrica) : base(fabrica) { }

        /// <inheritdoc />
        public List<Cliente> ListarClientes()
        {
            var lista = new List<Cliente>();
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_cliente_listar"))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    lista.Add(new Cliente
                    {
                        Id = r.Entero("id_cliente"),
                        Nit = r.Texto("nit"),
                        RazonSocial = r.Texto("razon_social"),
                        Sector = r.Texto("sector"),
                        Ciudad = r.Texto("ciudad"),
                        FechaAlta = r.Fecha("fecha_alta"),
                        PolizasVigentes = r.Entero("polizas_vigentes")
                    });
                }
            }
            return lista;
        }

        /// <inheritdoc />
        public List<Poliza> ListarPolizas()
        {
            var lista = new List<Poliza>();
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_poliza_listar"))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    lista.Add(new Poliza
                    {
                        Id = r.Entero("id_poliza"),
                        Numero = r.Texto("numero"),
                        Cliente = r.Texto("cliente"),
                        Ramo = r.Texto("ramo"),
                        Aseguradora = r.Texto("aseguradora"),
                        Prima = r.EnteroLargo("prima"),
                        VigenciaDesde = r.Fecha("vigencia_desde"),
                        VigenciaHasta = r.Fecha("vigencia_hasta"),
                        Estado = r.Texto("estado"),
                        DiasParaVencer = r.Entero("dias_para_vencer")
                    });
                }
            }
            return lista;
        }

        /// <inheritdoc />
        public List<Siniestro> ListarSiniestros()
        {
            var lista = new List<Siniestro>();
            using (var cn = Fabrica.Abrir())
            using (var cmd = CrearComando(cn, "sp_siniestro_listar"))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    lista.Add(new Siniestro
                    {
                        Id = r.Entero("id_siniestro"),
                        Numero = r.Texto("numero"),
                        Poliza = r.Texto("poliza"),
                        Cliente = r.Texto("cliente"),
                        FechaAviso = r.Fecha("fecha_aviso"),
                        Descripcion = r.Texto("descripcion"),
                        ValorReclamado = r.EnteroLargo("valor_reclamado"),
                        Estado = r.Texto("estado")
                    });
                }
            }
            return lista;
        }
    }
}
