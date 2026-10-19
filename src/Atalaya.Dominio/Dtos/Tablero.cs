using System;
using System.Collections.Generic;

namespace Atalaya.Dominio.Dtos
{
    /// <summary>
    /// Respuesta de <c>GET /api/tablero</c>: los cuatro resultsets de <c>sp_tablero_kpis</c>.
    /// </summary>
    public class Tablero
    {
        /// <summary>Indicadores numéricos (resultset 1).</summary>
        public Kpis Kpis { get; set; }

        /// <summary>Serie diaria de 14 días (resultset 2).</summary>
        public List<PuntoSerie> Serie { get; set; } = new List<PuntoSerie>();

        /// <summary>Usuarios por menú (resultset 3).</summary>
        public List<UsoMenu> UsoMenus { get; set; } = new List<UsoMenu>();

        /// <summary>Matriz usuario × menú (resultset 4).</summary>
        public List<CeldaMatriz> Matriz { get; set; } = new List<CeldaMatriz>();
    }

    /// <summary>Indicadores del tablero.</summary>
    public class Kpis
    {
        /// <summary>Usuarios registrados.</summary>
        public int UsuariosTotal { get; set; }
        /// <summary>Usuarios activos.</summary>
        public int UsuariosActivos { get; set; }
        /// <summary>Menús activos.</summary>
        public int MenusActivos { get; set; }
        /// <summary>Filas de usuario_menu.</summary>
        public int AsignacionesTotal { get; set; }
        /// <summary>Logins exitosos hoy.</summary>
        public int LoginsHoy { get; set; }
        /// <summary>Accesos denegados en 7 días.</summary>
        public int Denegados7d { get; set; }
        /// <summary>Logins fallidos en 7 días.</summary>
        public int Fallidos7d { get; set; }
        /// <summary>Cuentas bloqueadas en este momento.</summary>
        public int BloqueadosAhora { get; set; }
    }

    /// <summary>Un día de la serie de actividad.</summary>
    public class PuntoSerie
    {
        /// <summary>Día.</summary>
        public DateTime Dia { get; set; }
        /// <summary>Logins exitosos.</summary>
        public int LoginsOk { get; set; }
        /// <summary>Logins fallidos.</summary>
        public int LoginsFallidos { get; set; }
        /// <summary>Accesos denegados.</summary>
        public int AccesosDenegados { get; set; }
    }

    /// <summary>Uso de un menú.</summary>
    public class UsoMenu
    {
        /// <summary>Código del menú.</summary>
        public string Codigo { get; set; }
        /// <summary>Nombre del menú.</summary>
        public string Nombre { get; set; }
        /// <summary>Usuarios que lo tienen asignado.</summary>
        public int TotalUsuarios { get; set; }
    }

    /// <summary>Una asignación usuario-menú.</summary>
    public class CeldaMatriz
    {
        /// <summary>Usuario.</summary>
        public int IdUsuario { get; set; }
        /// <summary>Nombre de usuario.</summary>
        public string Usuario { get; set; }
        /// <summary>Código del menú asignado.</summary>
        public string Codigo { get; set; }
    }
}
