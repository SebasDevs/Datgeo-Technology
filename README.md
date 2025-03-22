Aplicación Flutter para registrar restaurantes y sincronizar datos con una API.

🚀 Funcionalidades Implementadas
🏠 Pantalla Principal (Home)
Muestra el total de restaurantes registrados y los pendientes de sincronización.

Botón para descargar los tipos de foto desde la API.

Mapa interactivo con OpenLayers que muestra:

Ubicación actual del usuario.

Restaurantes registrados.

🗺️ Mapa
Implementado con OpenLayers.

Obtiene la ubicación del usuario con Geolocator.

Muestra marcadores para los restaurantes:

🔴 Rojo: No sincronizados.

⚫ Negro: Sincronizados.

Permite registrar restaurantes al hacer clic en el mapa.

📋 Formulario de Registro de Restaurante
📝 Pestaña 1: Datos
Campos: Nombre, RUC (validado, 11 dígitos), Latitud, Longitud (automáticas), Comentario (opcional).

📷 Pestaña 2: Fotos
Permite capturar hasta 3 fotos:

Fachada Frontal

Fachada Lateral Derecha

Fachada Lateral Izquierda

Vista previa de cada foto.

Registro de fecha y hora de captura.

💾 Guardado y Sincronización
Guarda los restaurantes en SQLite usando sqflite.

Si hay conexión a internet, sincroniza datos y fotos con la API.

Las fotos se suben a S3 usando URLs firmadas.

Previene duplicados verificando el RUC antes de guardar.

🌐 Integración con API
Verifica API: /health-check

Descarga tipos de foto: /photo-types

Registra restaurantes: /restaurants (POST, retorna uuid)

Obtiene URLs para subir fotos: /signed-url

Sube fotos a S3: Método PUT

Usa API Key (x-api-key) en todas las solicitudes, excepto /health-check.

## APK

El APK de la aplicación está disponible para su descarga:

- [Descargar APK](app-release.apk)