using System.Collections.Generic;
using Atalaya.Dominio.Dtos;
using Atalaya.Dominio.Entidades;
using Atalaya.Dominio.Seguridad;

namespace Atalaya.Dominio.Interfaces
{
    /// <summary>
    /// Acceso a usuarios. La implementación llama SPs; la API solo conoce esta interfaz.
    /// </summary>
    /// <remarks>Separar contrato e implementación permite probar controladores con dobles sin BD.</remarks>
    public interface IRepositorioUsuarios
    {
        /// <summary>Lista usuarios; <paramref name="buscar"/> filtra por nombre, usuario o correo (null = todos).</summary>
        List<UsuarioDto> Listar(string buscar);

        /// <summary>Obtiene un usuario o <c>null</c> si no existe.</summary>
        UsuarioDto Obtener(int idUsuario);

        /// <summary>Busca por usuario O correo los datos necesarios para el login; <c>null</c> si no existe.</summary>
        UsuarioParaLogin ObtenerParaLogin(string login);

        /// <summary>Registra un intento de login y aplica la regla de bloqueo (5 fallos → 15 min).</summary>
        ResultadoIntentoLogin RegistrarLogin(int idUsuario, bool exitoso, string ip);

        /// <summary>Crea el usuario y devuelve su id. Lanza <c>ConflictoException</c> si el usuario o correo ya existen.</summary>
        int Crear(string nombre, string usuario, string correo, ClaveDerivada clave, bool activo, int? creadoPor);

        /// <summary>Activa o inactiva; devuelve las filas afectadas.</summary>
        int CambiarEstado(int idUsuario, bool activo);

        /// <summary>Consulta si el usuario (activo) tiene asignado el menú (activo) indicado.</summary>
        bool TieneMenu(int idUsuario, string codigoMenu);
    }

    /// <summary>
    /// Acceso a menús y asignaciones.
    /// </summary>
    public interface IRepositorioMenus
    {
        /// <summary>Catálogo de menús con total de usuarios.</summary>
        List<MenuDto> Listar(bool soloActivos);

        /// <summary>Menús activos asignados a un usuario.</summary>
        List<MenuDto> ListarDeUsuario(int idUsuario);

        /// <summary>Reemplaza en una transacción la asignación completa; devuelve (agregados, retirados).</summary>
        ResultadoAsignacion Reemplazar(int idUsuario, IEnumerable<int> idsMenu, int? asignadoPor);
    }

    /// <summary>
    /// Bitácora de accesos (auditoría).
    /// </summary>
    public interface IRepositorioBitacora
    {
        /// <summary>Registra un evento.</summary>
        void Registrar(NuevoEventoBitacora evento);

        /// <summary>Últimos eventos, opcionalmente filtrados por código.</summary>
        List<EventoBitacora> Listar(string evento, int limite);
    }

    /// <summary>
    /// Indicadores del tablero.
    /// </summary>
    public interface IRepositorioTablero
    {
        /// <summary>Lee los cuatro resultsets de <c>sp_tablero_kpis</c>.</summary>
        Tablero Obtener();
    }

    /// <summary>
    /// Datos de negocio demo (clientes, pólizas, siniestros).
    /// </summary>
    public interface IRepositorioNegocio
    {
        /// <summary>Clientes con pólizas vigentes.</summary>
        List<Cliente> ListarClientes();

        /// <summary>Pólizas con días para vencer.</summary>
        List<Poliza> ListarPolizas();

        /// <summary>Siniestros con póliza y cliente.</summary>
        List<Siniestro> ListarSiniestros();
    }

    /// <summary>
    /// Verificación de disponibilidad de la base de datos.
    /// </summary>
    public interface IVerificadorSalud
    {
        /// <summary><c>true</c> si la BD responde.</summary>
        bool BaseDatosDisponible();
    }
}
