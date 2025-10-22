# ✅ Checklist de Pruebas - Mi Agenda

## 📋 **Pre-requisitos en Firebase Console**

Marca cada item que hayas completado:

### 🔥 Firebase Console (https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d)

- [ ] **Firestore Database creado**
  - Verifica: Ve a "Firestore Database" → Debe mostrar la base de datos
  - Ubicación: southamerica-east1
  - Modo: Prueba (test mode)

- [ ] **Authentication habilitado**
  - Verifica: "Authentication" → "Sign-in method"
  - Métodos habilitados:
    - [ ] Anonymous (REQUERIDO para funcionamiento automático)
    - [ ] Email/Password (opcional, ya configurado)

- [ ] **Reglas de Firestore configuradas**
  - Ve a: "Firestore Database" → "Reglas"
  - Debe tener:
    ```javascript
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        match /{document=**} {
          allow read, write: if true;
        }
      }
    }
    ```

### 📱 **Archivos locales**

- [x] `android/app/google-services.json` existe ✓
- [x] `lib/firebase_options.dart` generado ✓
- [x] Dependencias instaladas (`flutter pub get`) ✓
- [ ] Dispositivo Android conectado o emulador corriendo

---

## 🧪 **Plan de Pruebas**

### **Prueba 1: Compilación**
```bash
flutter build apk --debug
```
**Resultado esperado:** APK se genera sin errores

### **Prueba 2: Iniciar App**
```bash
flutter run
```
**Resultado esperado:**
- App se instala en el dispositivo
- No hay crashes en el inicio
- Aparece pantalla de calendario

### **Prueba 3: Firebase Autenticación**
**Logs a buscar:**
```
Usuario autenticado anónimamente: [ID]
```
**Cómo verificar:**
- En Firebase Console → Authentication → Users
- Debe aparecer un usuario anónimo

### **Prueba 4: Crear Evento**
**Pasos:**
1. Tap en botón "+"
2. Llenar: Título, Descripción, Fecha, Hora, Categoría
3. Guardar

**Resultado esperado:**
- Evento aparece en el calendario
- Se marca el día en el calendario
- Evento aparece en lista del día

### **Prueba 5: Sincronización Firebase**
**Verificar en Firebase Console:**
1. Ve a "Firestore Database" → "Datos"
2. Debe aparecer colección `events`
3. Dentro debe haber un documento con tu evento
4. Campos visibles: title, description, startTime, category, userId, etc.

### **Prueba 6: Notificaciones**
**Pasos:**
1. Crear evento para dentro de 15 minutos
2. Esperar
3. Debe llegar notificación 15 min antes

**Resultado esperado:**
- Notificación aparece
- Al tocarla abre el detalle del evento

### **Prueba 7: Editar Evento**
**Pasos:**
1. Tap en un evento existente
2. Tap en ícono de editar
3. Cambiar título
4. Guardar

**Resultado esperado:**
- Cambios se reflejan inmediatamente
- Firebase Console muestra el cambio

### **Prueba 8: Eliminar Evento**
**Pasos:**
1. Abrir detalle de evento
2. Tap en eliminar
3. Confirmar

**Resultado esperado:**
- Evento desaparece del calendario
- Evento se elimina de Firebase

### **Prueba 9: Modo Offline**
**Pasos:**
1. Activar modo avión
2. Crear un evento
3. Verificar que se guarda localmente
4. Desactivar modo avión
5. Esperar sincronización

**Resultado esperado:**
- App funciona sin conexión
- Evento se guarda en SQLite
- Al reconectar, se sube a Firebase

### **Prueba 10: Tema Claro/Oscuro**
**Pasos:**
1. Cambiar tema del sistema (o en ajustes de app si existe)
2. Verificar que la app cambia

**Resultado esperado:**
- Tema se actualiza correctamente
- Colores se adaptan

### **Prueba 11: Categorías**
**Verificar:**
- Todas las categorías aparecen: Trabajo, Personal, Salud, Estudio, Social
- Cada una tiene su icono y color
- Filtrado por categoría funciona

### **Prueba 12: Múltiples Eventos**
**Pasos:**
1. Crear 5-10 eventos diferentes
2. Verificar rendimiento
3. Navegar por diferentes meses

**Resultado esperado:**
- Navegación fluida
- No hay lag
- Todos los eventos se muestran correctamente

---

## 🐛 **Checklist de Problemas Comunes**

Si algo falla, verifica:

### Error: "No Firebase App has been created"
- [ ] Verificar que `firebase_options.dart` existe
- [ ] Verificar que `Firebase.initializeApp()` se llama en `main.dart`
- [ ] Limpiar proyecto: `flutter clean && flutter pub get`

### Error: "Permission denied" en Firestore
- [ ] Verificar reglas de Firestore en modo de prueba
- [ ] Verificar que Authentication Anonymous está habilitado
- [ ] Revisar logs para ver si la autenticación se completó

### App compila pero no guarda eventos
- [ ] Verificar logs en `flutter run` para errores
- [ ] Verificar conexión a internet
- [ ] Verificar que Firestore Database está creada (no solo activada)
- [ ] Verificar en Firebase Console → Firestore → Datos si aparecen colecciones

### Notificaciones no llegan
- [ ] Verificar permisos de notificación en el dispositivo
- [ ] Verificar que el evento está programado a futuro
- [ ] Revisar logs de `NotificationService`

### Sincronización no funciona
- [ ] Verificar conexión a internet
- [ ] Verificar que usuario está autenticado (ver logs)
- [ ] Verificar reglas de Firestore
- [ ] Limpiar caché: `flutter clean`

---

## 📊 **Resultado de Pruebas**

| Prueba | Estado | Notas |
|--------|--------|-------|
| 1. Compilación | ⏳ | |
| 2. Iniciar App | ⏳ | |
| 3. Firebase Auth | ⏳ | |
| 4. Crear Evento | ⏳ | |
| 5. Sincronización | ⏳ | |
| 6. Notificaciones | ⏳ | |
| 7. Editar Evento | ⏳ | |
| 8. Eliminar Evento | ⏳ | |
| 9. Modo Offline | ⏳ | |
| 10. Temas | ⏳ | |
| 11. Categorías | ⏳ | |
| 12. Rendimiento | ⏳ | |

**Leyenda:**
- ⏳ Pendiente
- ✅ Pasó
- ❌ Falló
- ⚠️ Parcial

---

## 🎯 **Próximos Pasos**

Una vez que todas las pruebas pasen:
1. Documentar cualquier bug encontrado
2. Crear issues/tareas para bugs
3. Proceder con siguiente fase: Sistema de Tareas

**Fecha de pruebas:** [COMPLETAR]
**Probado por:** [COMPLETAR]
**Dispositivo:** [COMPLETAR]
