#!/bin/bash

# Script para limpiar sesión de Firebase y forzar logout
# Uso: ./scripts/clear_firebase_auth.sh

echo "🧹 Limpiando datos de autenticación de Firebase..."
echo ""

# Detener la app si está corriendo
echo "1. Deteniendo la app..."
pkill -f "flutter run" 2>/dev/null || echo "   ⚠️  App no está corriendo"

# Limpiar caché de Flutter
echo ""
echo "2. Limpiando caché de Flutter..."
cd "$(dirname "$0")/.." || exit
flutter clean

# Reinstalar dependencias
echo ""
echo "3. Reinstalando dependencias..."
flutter pub get

# Instrucciones para limpiar Firebase Auth manualmente
echo ""
echo "4. 🔥 Limpieza manual de Firebase Auth:"
echo "   Abre: https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/authentication/users"
echo "   - Si ves usuarios con email 'null' o sin email → Elimínalos (son usuarios anónimos)"
echo "   - También puedes eliminar todos los usuarios para empezar de cero"
echo ""

# Dar opción de ejecutar la app
echo "5. ¿Ejecutar la app ahora? (s/n)"
read -r response
if [[ "$response" =~ ^[Ss]$ ]]; then
    echo ""
    echo "▶️  Ejecutando la app..."
    flutter run -d infinix
else
    echo ""
    echo "✅ Limpieza completada. Para ejecutar la app:"
    echo "   flutter run -d infinix"
fi
