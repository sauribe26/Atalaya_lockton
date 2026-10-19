using System;
using System.Collections.Generic;

namespace Atalaya.Dominio.Excepciones
{
    /// <summary>
    /// Base de los errores esperados del negocio. Cada uno sabe su código HTTP y su código funcional.
    /// </summary>
    /// <remarks>
    /// Las capas internas lanzan estas excepciones sin saber nada de HTTP más allá del número;
    /// el manejador global las convierte al formato de error del contrato. Así los controladores
    /// no se llenan de try/catch.
    /// </remarks>
    public abstract class ExcepcionNegocio : Exception
    {
        /// <summary>Crea la excepción.</summary>
        /// <param name="estadoHttp">Código HTTP a responder.</param>
        /// <param name="codigo">Código funcional (ej. <c>USUARIO_DUPLICADO</c>).</param>
        /// <param name="mensaje">Mensaje legible.</param>
        protected ExcepcionNegocio(int estadoHttp, string codigo, string mensaje) : base(mensaje)
        {
            EstadoHttp = estadoHttp;
            Codigo = codigo;
        }

        /// <summary>Código HTTP.</summary>
        public int EstadoHttp { get; }

        /// <summary>Código funcional.</summary>
        public string Codigo { get; }

        /// <summary>Detalle por campo (solo validaciones).</summary>
        public virtual Dictionary<string, string> Detalles => null;
    }

    /// <summary>409: conflicto con el estado actual (duplicados, autobloqueo, autoinactivación).</summary>
    public class ConflictoException : ExcepcionNegocio
    {
        /// <summary>Crea el conflicto.</summary>
        /// <param name="codigo">Código funcional.</param>
        /// <param name="mensaje">Mensaje legible.</param>
        public ConflictoException(string codigo, string mensaje) : base(409, codigo, mensaje) { }
    }

    /// <summary>404: el recurso pedido no existe.</summary>
    public class NoEncontradoException : ExcepcionNegocio
    {
        /// <summary>Crea el error.</summary>
        /// <param name="codigo">Código funcional (ej. <c>USUARIO_NO_ENCONTRADO</c>).</param>
        /// <param name="mensaje">Mensaje legible.</param>
        public NoEncontradoException(string codigo, string mensaje) : base(404, codigo, mensaje) { }
    }

    /// <summary>400: datos inválidos detectados por reglas de negocio (no por DataAnnotations).</summary>
    public class SolicitudInvalidaException : ExcepcionNegocio
    {
        private readonly Dictionary<string, string> _detalles;

        /// <summary>Crea el error.</summary>
        /// <param name="codigo">Código funcional.</param>
        /// <param name="mensaje">Mensaje legible.</param>
        /// <param name="detalles">Campo → mensaje (opcional).</param>
        public SolicitudInvalidaException(string codigo, string mensaje, Dictionary<string, string> detalles = null)
            : base(400, codigo, mensaje)
        {
            _detalles = detalles;
        }

        /// <inheritdoc />
        public override Dictionary<string, string> Detalles => _detalles;
    }
}
