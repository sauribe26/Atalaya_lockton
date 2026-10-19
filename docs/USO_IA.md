# Declaración de uso de herramientas de inteligencia artificial

Según la sección 5 de la prueba, declaro las herramientas de IA usadas y cómo se emplearon.

| Herramienta | Uso |
|---|---|
| **Claude Code** (Anthropic, modelo Claude Opus) en la terminal de Windows | Asistente de programación. Lo usé para analizar el requerimiento, proponer la arquitectura y el contrato técnico (`docs/CONTRATO.md`), y generar el primer borrador del código en tres frentes: base de datos, API y front. |

## Cómo se trabajó

1. **Análisis y diseño (yo + IA):** a partir del PDF definí el alcance. Con la IA escribí un contrato único (tablas, procedimientos, endpoints, códigos HTTP, pantallas) que sirvió de fuente de verdad.
2. **Generación por frentes:** la IA generó los scripts SQL, la API en C# y el front a partir de ese contrato.
3. **Diseño visual:** la interfaz se basa en el lenguaje visual de un aplicativo interno que ya desarrollé (paleta, barra lateral, login de dos paneles), adaptado a Bootstrap 5. La marca "Atalaya" y su logo son propios de esta prueba.
4. **Verificación:** compilé la solución, ejecuté los scripts contra MySQL y probé cada endpoint (incluidos los casos 401, 403, 409 y 423). Además revisé el código para poder explicarlo y modificarlo en la sustentación.

## Responsabilidad

Entiendo y puedo explicar todo el código entregado: el modelo de datos, el hash PBKDF2 con sal, el flujo JWT, el filtro `[RequiereMenu]` que autoriza en el servidor en cada petición, el manejo de errores y el menú dinámico del front.
