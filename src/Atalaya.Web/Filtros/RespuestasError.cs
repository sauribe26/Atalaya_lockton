using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using Atalaya.Dominio.Dtos;

namespace Atalaya.Web.Filtros
{
    /// <summary>
    /// Fábrica única de respuestas de error con el formato del contrato
    /// (<c>estado, codigo, mensaje, detalles, traza</c>).
    /// </summary>
    public static class RespuestasError
    {
        /// <summary>Genera un identificador de traza corto para correlacionar con el log.</summary>
        public static string NuevaTraza()
        {
            return Guid.NewGuid().ToString("N").Substring(0, 16);
        }

        /// <summary>
        /// Crea la respuesta HTTP de error usando el formateador JSON configurado (camelCase).
        /// </summary>
        /// <param name="request">Petición actual.</param>
        /// <param name="estado">Código HTTP.</param>
        /// <param name="codigo">Código funcional.</param>
        /// <param name="mensaje">Mensaje legible.</param>
        /// <param name="detalles">Detalle por campo (solo validaciones).</param>
        /// <param name="traza">Traza ya generada (si se registró en el log); si es null se genera una.</param>
        public static HttpResponseMessage Crear(HttpRequestMessage request, HttpStatusCode estado, string codigo,
            string mensaje, Dictionary<string, string> detalles = null, string traza = null)
        {
            var cuerpo = new ErrorApi
            {
                Estado = (int)estado,
                Codigo = codigo,
                Mensaje = mensaje,
                Detalles = detalles,
                Traza = traza ?? NuevaTraza()
            };
            return request.CreateResponse(estado, cuerpo);
        }
    }
}
