using System;
using System.Globalization;
using System.Net;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using Atalaya.Dominio.Seguridad;
using Atalaya.Web.Filtros;

namespace Atalaya.Web.Seguridad
{
    /// <summary>
    /// Autorización por menú: el usuario autenticado debe tener asignado (y activo) el menú indicado.
    /// </summary>
    /// <remarks>
    /// <para>Es el corazón de la seguridad: la barra lateral del front solo es una comodidad visual;
    /// quien decide es este filtro, en el servidor, en CADA petición.</para>
    /// <para>Consulta <c>sp_usuario_tiene_menu</c> cada vez en lugar de leer los menús del token, para que
    /// retirar un menú o inactivar al usuario corte el acceso de inmediato. El costo es una consulta
    /// indexada por petición, aceptable para este volumen.</para>
    /// <para>Responde 401 si no hay sesión y 403 si no hay permiso; el 403 queda en la bitácora
    /// como <c>ACCESO_DENEGADO</c> con la IP del cliente.</para>
    /// </remarks>
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false, Inherited = true)]
    public class RequiereMenuAttribute : AuthorizationFilterAttribute
    {
        /// <summary>Crea el filtro para el menú indicado.</summary>
        /// <param name="codigoMenu">Código funcional del menú (ej. <c>USUARIOS</c>).</param>
        public RequiereMenuAttribute(string codigoMenu)
        {
            CodigoMenu = codigoMenu;
        }

        /// <summary>Código del menú requerido.</summary>
        public string CodigoMenu { get; }

        /// <summary>
        /// Si es <c>true</c>, también se permite el acceso cuando el parámetro de ruta <c>id</c> es el
        /// propio usuario (ej. un usuario puede consultar sus propios menús sin tener ASIGNACION).
        /// </summary>
        public bool PermitirPropioUsuario { get; set; }

        /// <summary>Evalúa autenticación y permiso antes de ejecutar la acción.</summary>
        public override void OnAuthorization(HttpActionContext actionContext)
        {
            var principal = actionContext.RequestContext.Principal;
            var idUsuario = ContextoPeticion.IdUsuario(principal);
            if (idUsuario == null)
            {
                actionContext.Response = RequiereAutenticacionAttribute.Responder401(actionContext);
                return;
            }

            if (PermitirPropioUsuario && EsPropioUsuario(actionContext, idUsuario.Value))
            {
                return;
            }

            if (Composicion.Usuarios().TieneMenu(idUsuario.Value, CodigoMenu))
            {
                return;
            }

            var login = ContextoPeticion.Login(principal);
            RegistroBitacora.Registrar(Composicion.Bitacora(), actionContext.Request, EventosBitacora.AccesoDenegado,
                idUsuario, login, "Menú requerido: " + CodigoMenu);

            actionContext.Response = RespuestasError.Crear(actionContext.Request, HttpStatusCode.Forbidden,
                "ACCESO_DENEGADO", "No tiene autorización para el menú " + CodigoMenu + ".");
        }

        private static bool EsPropioUsuario(HttpActionContext actionContext, int idUsuario)
        {
            object valor;
            if (!actionContext.RequestContext.RouteData.Values.TryGetValue("id", out valor) || valor == null)
                return false;
            int idRuta;
            return int.TryParse(Convert.ToString(valor, CultureInfo.InvariantCulture), NumberStyles.Integer,
                       CultureInfo.InvariantCulture, out idRuta) && idRuta == idUsuario;
        }
    }
}
