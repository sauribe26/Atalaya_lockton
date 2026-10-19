using System;
using Atalaya.Datos;
using Atalaya.Datos.Repositorios;
using Atalaya.Dominio.Interfaces;
using Atalaya.Web.Seguridad;

namespace Atalaya.Web
{
    /// <summary>
    /// Raíz de composición: el único lugar donde se decide qué implementación concreta usa la API.
    /// </summary>
    /// <remarks>
    /// Para un proyecto de este tamaño un contenedor de inyección sería más ceremonia que beneficio.
    /// Los controladores igual reciben interfaces por constructor (testeables); su constructor sin
    /// parámetros, que es el que usa Web API, toma las implementaciones de aquí.
    /// </remarks>
    public static class Composicion
    {
        private static readonly Lazy<FabricaConexion> Fabrica = new Lazy<FabricaConexion>(() => new FabricaConexion());

        /// <summary>Servicio de emisión y validación de tokens (único por aplicación).</summary>
        public static ServicioJwt Jwt { get; private set; }

        /// <summary>
        /// Carga la configuración de seguridad. Falla al arrancar si falta la clave JWT.
        /// </summary>
        public static void Inicializar()
        {
            Jwt = ServicioJwt.DesdeConfiguracion();
        }

        /// <summary>Repositorio de usuarios.</summary>
        public static IRepositorioUsuarios Usuarios() => new RepositorioUsuarios(Fabrica.Value);

        /// <summary>Repositorio de menús.</summary>
        public static IRepositorioMenus Menus() => new RepositorioMenus(Fabrica.Value);

        /// <summary>Repositorio de bitácora.</summary>
        public static IRepositorioBitacora Bitacora() => new RepositorioBitacora(Fabrica.Value);

        /// <summary>Repositorio del tablero.</summary>
        public static IRepositorioTablero Tablero() => new RepositorioTablero(Fabrica.Value);

        /// <summary>Repositorio de negocio demo.</summary>
        public static IRepositorioNegocio Negocio() => new RepositorioNegocio(Fabrica.Value);

        /// <summary>Verificador de salud de la BD.</summary>
        public static IVerificadorSalud Salud() => new VerificadorSalud(() => Fabrica.Value);
    }
}
