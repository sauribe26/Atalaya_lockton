using System;
using System.Configuration;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Atalaya.Dominio.Entidades;
using Microsoft.IdentityModel.Tokens;

namespace Atalaya.Web.Seguridad
{
    /// <summary>
    /// Emite y valida los JWT de la API (HS256, emisor <c>Atalaya</c>, vigencia de 8 horas).
    /// </summary>
    /// <remarks>
    /// El token solo prueba <em>quién</em> es el usuario. Qué puede hacer (menús) NO va en el token:
    /// se consulta en la BD en cada petición, para que quitar un menú o inactivar un usuario tenga efecto
    /// inmediato sin esperar a que el token expire.
    /// </remarks>
    public class ServicioJwt
    {
        /// <summary>Nombre del appSetting con la clave de firma (en Secretos.config).</summary>
        public const string ClaveConfiguracion = "Jwt:Clave";

        /// <summary>Longitud mínima aceptada para la clave (256 bits si son caracteres aleatorios).</summary>
        public const int LongitudMinimaClave = 32;

        /// <summary>Claim con el nombre completo.</summary>
        public const string ClaimNombre = "name";

        private readonly SymmetricSecurityKey _llave;
        private readonly string _emisor;
        private readonly TimeSpan _vigencia;

        /// <summary>
        /// Crea el servicio.
        /// </summary>
        /// <param name="clave">Clave de firma (≥ 32 caracteres).</param>
        /// <param name="emisor">Emisor y audiencia del token.</param>
        /// <param name="vigencia">Tiempo de vida del token.</param>
        public ServicioJwt(string clave, string emisor, TimeSpan vigencia)
        {
            if (string.IsNullOrWhiteSpace(clave) || clave.Length < LongitudMinimaClave)
            {
                throw new ConfigurationErrorsException(
                    "Falta la clave JWT o es muy corta. Copie Secretos.example.config como Secretos.config " +
                    "y ponga en 'Jwt:Clave' un valor aleatorio de al menos " + LongitudMinimaClave + " caracteres.");
            }
            _llave = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(clave));
            _emisor = emisor;
            _vigencia = vigencia;
        }

        /// <summary>
        /// Construye el servicio leyendo <c>Jwt:Clave</c>, <c>Jwt:Emisor</c> y <c>Jwt:HorasVigencia</c> de appSettings.
        /// </summary>
        public static ServicioJwt DesdeConfiguracion()
        {
            var ajustes = ConfigurationManager.AppSettings;
            var emisor = string.IsNullOrWhiteSpace(ajustes["Jwt:Emisor"]) ? "Atalaya" : ajustes["Jwt:Emisor"];
            int horas;
            if (!int.TryParse(ajustes["Jwt:HorasVigencia"], NumberStyles.Integer, CultureInfo.InvariantCulture, out horas) || horas <= 0)
            {
                horas = 8;
            }
            return new ServicioJwt(ajustes[ClaveConfiguracion], emisor, TimeSpan.FromHours(horas));
        }

        /// <summary>
        /// Emite un token para el usuario autenticado.
        /// </summary>
        /// <param name="usuario">Usuario que acaba de iniciar sesión.</param>
        /// <param name="expiraEn">Momento de expiración (UTC).</param>
        /// <returns>Token compacto (header.payload.firma).</returns>
        public string Emitir(UsuarioResumen usuario, out DateTime expiraEn)
        {
            var ahora = DateTime.UtcNow;
            expiraEn = ahora.Add(_vigencia);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, usuario.Id.ToString(CultureInfo.InvariantCulture)),
                new Claim(JwtRegisteredClaimNames.UniqueName, usuario.Usuario),
                new Claim(ClaimNombre, usuario.Nombre ?? string.Empty),
                // jti único: permitiría revocar tokens puntuales con una lista negra si se necesitara.
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N"))
            };

            var token = new JwtSecurityToken(
                issuer: _emisor,
                audience: _emisor,
                claims: claims,
                notBefore: ahora,
                expires: expiraEn,
                signingCredentials: new SigningCredentials(_llave, SecurityAlgorithms.HmacSha256));

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        /// <summary>
        /// Valida firma, emisor, audiencia y vigencia del token.
        /// </summary>
        /// <param name="token">Token recibido en el encabezado Authorization.</param>
        /// <returns>Principal con los claims del token.</returns>
        /// <exception cref="SecurityTokenExpiredException">Si el token expiró.</exception>
        /// <exception cref="SecurityTokenException">Si la firma o los datos no son válidos.</exception>
        public ClaimsPrincipal Validar(string token)
        {
            var manejador = new JwtSecurityTokenHandler();
            // Sin esto el manejador renombra "sub" y "unique_name" a los ClaimTypes largos de WS-*.
            manejador.InboundClaimTypeMap.Clear();

            var parametros = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = _llave,
                ValidateIssuer = true,
                ValidIssuer = _emisor,
                ValidateAudience = true,
                ValidAudience = _emisor,
                ValidateLifetime = true,
                RequireExpirationTime = true,
                RequireSignedTokens = true,
                ClockSkew = TimeSpan.FromMinutes(1),
                NameClaimType = JwtRegisteredClaimNames.UniqueName
            };

            SecurityToken validado;
            var principal = manejador.ValidateToken(token, parametros, out validado);

            // Solo se acepta HS256: evita que alguien negocie otro algoritmo en el header.
            var jwt = validado as JwtSecurityToken;
            if (jwt == null || !string.Equals(jwt.Header.Alg, SecurityAlgorithms.HmacSha256, StringComparison.Ordinal))
            {
                throw new SecurityTokenException("Algoritmo de firma no permitido.");
            }
            return principal;
        }
    }
}
