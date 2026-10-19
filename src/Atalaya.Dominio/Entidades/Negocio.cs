using System;

namespace Atalaya.Dominio.Entidades
{
    /// <summary>
    /// Cliente del broker (datos demo ficticios).
    /// </summary>
    public class Cliente
    {
        /// <summary>Identificador.</summary>
        public int Id { get; set; }
        /// <summary>NIT.</summary>
        public string Nit { get; set; }
        /// <summary>Razón social.</summary>
        public string RazonSocial { get; set; }
        /// <summary>Sector económico.</summary>
        public string Sector { get; set; }
        /// <summary>Ciudad.</summary>
        public string Ciudad { get; set; }
        /// <summary>Fecha de vinculación.</summary>
        public DateTime FechaAlta { get; set; }
        /// <summary>Pólizas vigentes del cliente.</summary>
        public int PolizasVigentes { get; set; }
    }

    /// <summary>
    /// Póliza intermediada (datos demo ficticios).
    /// </summary>
    public class Poliza
    {
        /// <summary>Identificador.</summary>
        public int Id { get; set; }
        /// <summary>Número de póliza.</summary>
        public string Numero { get; set; }
        /// <summary>Razón social del cliente.</summary>
        public string Cliente { get; set; }
        /// <summary>Ramo (autos, vida, etc.).</summary>
        public string Ramo { get; set; }
        /// <summary>Aseguradora.</summary>
        public string Aseguradora { get; set; }
        /// <summary>Prima en pesos, entero (sin decimales para no depender de la cultura).</summary>
        public long Prima { get; set; }
        /// <summary>Inicio de vigencia.</summary>
        public DateTime VigenciaDesde { get; set; }
        /// <summary>Fin de vigencia.</summary>
        public DateTime VigenciaHasta { get; set; }
        /// <summary>VIGENTE, POR_RENOVAR o VENCIDA.</summary>
        public string Estado { get; set; }
        /// <summary>Días que faltan para el vencimiento (negativo si ya venció).</summary>
        public int DiasParaVencer { get; set; }
    }

    /// <summary>
    /// Siniestro reportado (datos demo ficticios).
    /// </summary>
    public class Siniestro
    {
        /// <summary>Identificador.</summary>
        public int Id { get; set; }
        /// <summary>Número de siniestro.</summary>
        public string Numero { get; set; }
        /// <summary>Número de la póliza afectada.</summary>
        public string Poliza { get; set; }
        /// <summary>Razón social del cliente.</summary>
        public string Cliente { get; set; }
        /// <summary>Fecha de aviso.</summary>
        public DateTime FechaAviso { get; set; }
        /// <summary>Descripción del siniestro.</summary>
        public string Descripcion { get; set; }
        /// <summary>Valor reclamado en pesos, entero.</summary>
        public long ValorReclamado { get; set; }
        /// <summary>ABIERTO, EN_AJUSTE, PAGADO u OBJETADO.</summary>
        public string Estado { get; set; }
    }
}
