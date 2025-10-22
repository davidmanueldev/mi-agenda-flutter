#!/bin/bash

# Script para configurar Firebase en Mi Agenda
# Ejecutar desde la raíz del proyecto Flutter

echo "🔥 Configurando Firebase para Mi Agenda..."

# Verificar si Flutter está instalado
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter no está instalado. Instala Flutter primero."
    exit 1
fi

# Verificar si Firebase CLI está instalado
if ! command -v firebase &> /dev/null; then
    echo "📦 Firebase CLI no encontrado. Instalando..."
    npm install -g firebase-tools
fi

# Verificar si FlutterFire CLI está instalado
if ! command -v flutterfire &> /dev/null; then
    echo "📦 FlutterFire CLI no encontrado. Instalando..."
    dart pub global activate flutterfire_cli
    
    # Agregar al PATH (para bash/zsh)
    if [[ ":$PATH:" != *":$HOME/.pub-cache/bin:"* ]]; then
        echo "➕ Agregando FlutterFire CLI al PATH..."
        echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.bashrc
        echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
        export PATH="$PATH:$HOME/.pub-cache/bin"
    fi
fi

echo ""
echo "🚀 PASOS PARA COMPLETAR LA CONFIGURACIÓN:"
echo ""
echo "1. 🌐 Ve a Firebase Console: https://console.firebase.google.com/"
echo "   - Crea un nuevo proyecto llamado 'mi-agenda-flutter'"
echo "   - Habilita Firestore Database en modo de prueba"
echo "   - Habilita Authentication → Sign-in method → Anónimo"
echo ""
echo "2. 🔑 Ejecuta los siguientes comandos:"
echo "   firebase login"
echo "   flutterfire configure --project=mi-agenda-flutter"
echo ""
echo "3. 📱 Configuración Android adicional:"
echo "   - El archivo google-services.json se colocará automáticamente"
echo "   - Verifica que android/app/build.gradle.kts tenga:"
echo "     plugins { id(\"com.google.gms.google-services\") }"
echo ""
echo "4. 🧪 Probar la configuración:"
echo "   flutter clean"
echo "   flutter pub get"
echo "   flutter run"
echo ""
echo "5. 📊 Verificar en Firebase Console:"
echo "   - Ve a Firestore Database"
echo "   - Deberías ver colecciones 'events' y 'categories' al usar la app"
echo ""
echo "📖 Para más detalles, lee FIREBASE_SETUP.md"
echo ""
echo "⚠️  IMPORTANTE: Configura reglas de Firestore apropiadas para producción!"
echo ""

# Verificar dependencias de Flutter
echo "🔍 Verificando dependencias..."
flutter pub get

echo "✅ Configuración inicial completada!"
echo "🔥 Sigue los pasos mostrados arriba para completar Firebase."
