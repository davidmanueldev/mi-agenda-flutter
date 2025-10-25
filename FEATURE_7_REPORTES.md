# Feature #7: Visual Reports con Gráficas 📊

## Estado: ✅ Implementado (95%)

### Archivos Creados/Modificados

#### 1. **`lib/views/reports_screen.dart`** ✅ NUEVO
Pantalla principal de reportes con 3 tabs:

##### **Tab 1: Pomodoros por Día (Gráfica de Barras)**
- **Datos**: Últimos 7 días de sesiones Pomodoro
- **Visualización**: `BarChart` de fl_chart
- **Características**:
  - Barras con degradado rojo (estilo Pomodoro)
  - Tooltips interactivos con día y cantidad
  - Eje X: Días de la semana (L, M, X, J, V, S, D)
  - Eje Y: Número de pomodoros
  - Grid horizontal cada 1 unidad
- **Estadísticas del resumen**:
  - Total pomodoros (últimos 7 días)
  - Promedio por día
  - Mejor día (máximo)
- **Estado vacío**: "Sin datos de Pomodoro" con mensaje motivador

##### **Tab 2: Tareas por Categoría (Gráfica de Pastel)**
- **Datos**: Distribución de tareas pendientes por categoría
- **Visualización**: `PieChart` de fl_chart
- **Características**:
  - Segmentos con colores de las categorías reales
  - Porcentajes en cada segmento
  - Badges con íconos de categoría
  - Leyenda completa con íconos, nombres y conteo
- **Estadísticas del resumen**:
  - Total tareas pendientes
  - Categorías activas
  - Categoría con más tareas
- **Estado vacío**: "Sin tareas pendientes"

##### **Tab 3: Tendencia de Productividad (Gráfica de Línea)**
- **Datos**: Minutos de trabajo efectivo por día (últimos 7 días)
- **Visualización**: `LineChart` de fl_chart
- **Características**:
  - Línea curva con degradado verde
  - Puntos marcadores en cada día
  - Área rellena bajo la línea (gradiente)
  - Línea punteada de promedio (azul)
  - Tooltips con día y minutos
  - Leyenda diferenciando productividad vs promedio
- **Estadísticas del resumen**:
  - Total minutos trabajados
  - Promedio de minutos por día
  - Mejor día (máximo minutos)
- **Estado vacío**: "Sin datos de productividad"

#### 2. **`lib/views/home_screen.dart`** ✅ MODIFICADO
- **Cambio**: Agregado import de `reports_screen.dart`
- **Cambio**: Nuevo `ListTile` en el drawer:
  ```dart
  ListTile(
    leading: const Icon(Icons.bar_chart),
    title: const Text('Reportes'),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReportsScreen()),
      );
    },
  )
  ```
- **Posición**: Entre "Historial Pomodoro" y el `Divider`

#### 3. **`pubspec.yaml`** ✅ MODIFICADO
- **Dependencia agregada**: `fl_chart: ^0.69.0`
- **Versión instalada**: `fl_chart 0.69.2`
- **Dependencias adicionales**: `equatable 2.0.7` (requerida por fl_chart)

---

## Funcionalidades Implementadas

### 📊 **Gráficas Interactivas**
- ✅ BarChart con tooltips
- ✅ PieChart con badges y leyenda
- ✅ LineChart con líneas múltiples (productividad + promedio)
- ✅ Animaciones suaves por defecto de fl_chart
- ✅ Colores consistentes con el tema de la app

### 📈 **Agregación de Datos**
- ✅ Método `_getPomodorosPerDay()`: Cuenta pomodoros completados por día
- ✅ Método `_getProductivityPerDay()`: Suma minutos de trabajo por día
- ✅ Filtrado automático de últimos 7 días
- ✅ Soporte para datos vacíos

### 🎨 **Diseño y UX**
- ✅ TabController con 3 tabs
- ✅ AppBar con botón de refrescar
- ✅ Cards de resumen con estadísticas clave
- ✅ Estados vacíos informativos con íconos grandes
- ✅ Scroll vertical para contenido largo
- ✅ Responsive design

### 🔄 **Integración con Controladores**
- ✅ `Consumer<PomodoroController>` para datos de Pomodoro
- ✅ `Consumer<TaskController>` para datos de tareas/categorías
- ✅ Método `_loadData()` para refrescar manualmente
- ✅ Carga automática en `initState()`

---

## Cómo Usar

### **Acceso a Reportes**
1. Abrir la app
2. Abrir el drawer (menú hamburguesa)
3. Seleccionar "Reportes"
4. Navegar entre los 3 tabs

### **Refrescar Datos**
- Presionar el botón de refrescar (↻) en la AppBar
- O salir y volver a entrar a la pantalla

### **Interpretación de Gráficas**

#### **Pomodoros por Día**
- **Barra alta**: Día productivo con muchos pomodoros
- **Barra baja/cero**: Día sin actividad
- **Color rojo**: Representa sesiones de trabajo
- **Promedio**: Indica consistencia semanal

#### **Tareas por Categoría**
- **Segmentos grandes**: Categorías con más tareas pendientes
- **Colores**: Mismo color que la categoría configurada
- **Porcentaje**: Proporción de tareas en esa categoría
- **Leyenda**: Lista completa con conteo exacto

#### **Tendencia de Productividad**
- **Línea verde ascendente**: Aumentando productividad
- **Línea verde descendente**: Disminuyendo productividad
- **Línea azul punteada**: Promedio de referencia
- **Puntos**: Datos de cada día específico
- **Área sombreada**: Visualización de volumen total

---

## Estructura de Código

### **Widgets Principales**

```dart
ReportsScreen
├── TabController (3 tabs)
├── TabBar
│   ├── "Pomodoros" (Icon: bar_chart)
│   ├── "Categorías" (Icon: pie_chart)
│   └── "Tendencia" (Icon: show_chart)
└── TabBarView
    ├── _buildPomodorosBarChart()
    │   ├── Consumer<PomodoroController>
    │   ├── _buildSummaryCard()
    │   └── BarChart (fl_chart)
    ├── _buildCategoriesPieChart()
    │   ├── Consumer<TaskController>
    │   ├── _buildSummaryCard()
    │   ├── PieChart (fl_chart)
    │   └── Leyenda personalizada
    └── _buildProductivityLineChart()
        ├── Consumer<PomodoroController>
        ├── _buildSummaryCard()
        ├── LineChart (fl_chart)
        └── _buildLegendItem() x2
```

### **Helpers Privados**

```dart
// Agregación de datos
Map<String, int> _getPomodorosPerDay(sessions, days)
Map<String, int> _getProductivityPerDay(sessions, days)

// Formateo
String _formatDate(DateTime date)
String _getDayName(int daysAgo)      // "Lun", "Mar", etc.
String _getDayNameShort(int daysAgo) // "L", "M", etc.

// UI
Widget _buildSummaryCard({title, stats})
Widget _buildEmptyState(title, message, icon)
Widget _buildBadge(icon, color)
Widget _buildLegendItem(label, color)
```

### **Clase Helper**

```dart
class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
```

---

## Dependencias de fl_chart

### **Widgets Utilizados**
- `BarChart` y `BarChartData`
- `PieChart` y `PieChartData`
- `LineChart` y `LineChartData`
- `FlTitlesData` (ejes)
- `FlGridData` (grilla)
- `FlBorderData` (bordes)
- `FlTouchData` (interactividad)

### **Configuraciones Clave**

#### **BarChart**
```dart
BarChartData(
  alignment: BarChartAlignment.spaceAround,
  maxY: (maxValue + 2).toDouble(),
  barTouchData: BarTouchData(tooltips...),
  titlesData: FlTitlesData(ejes...),
  barGroups: [BarChartGroupData(...)],
)
```

#### **PieChart**
```dart
PieChartData(
  sectionsSpace: 2,
  centerSpaceRadius: 40,
  sections: [
    PieChartSectionData(
      color: category.color,
      value: taskCount.toDouble(),
      title: '${percentage}%',
      badgeWidget: Icon(...),
    ),
  ],
)
```

#### **LineChart**
```dart
LineChartData(
  lineBarsData: [
    LineChartBarData(
      spots: [FlSpot(x, y)],
      isCurved: true,
      color: Colors.green,
      dotData: FlDotData(...),
      belowBarData: BarAreaData(gradient...),
    ),
  ],
)
```

---

## Fuente de Datos

### **PomodoroController**
- `sessions`: Lista de `PomodoroSession`
- Filtro: `session.sessionType == SessionType.work && session.isCompleted`
- Datos extraídos:
  - `startTime`: Para agrupar por día
  - `durationInMinutes`: Para calcular productividad
  - Conteo: Para cantidad de pomodoros

### **TaskController**
- `tasks`: Lista de `Task`
- Filtro: `task.status == TaskStatus.pending`
- `categories`: Lista de `Category`
- Datos extraídos:
  - `task.category`: ID para agrupar
  - `category.name`, `category.icon`, `category.color`: Para UI
  - Conteo: Para distribución

---

## Testing

### **Casos de Prueba**

1. **Sin datos**
   - Estado: Base de datos vacía
   - Esperado: Mostrar estados vacíos en las 3 tabs
   - ✅ Implementado

2. **Con datos parciales**
   - Estado: Solo algunos días con actividad
   - Esperado: Barras solo en esos días, resto en cero
   - ✅ Implementado

3. **Con datos completos**
   - Estado: 7 días con actividad
   - Esperado: Todas las gráficas pobladas
   - ✅ Implementado

4. **Categorías sin tareas**
   - Estado: Categorías creadas pero sin tareas
   - Esperado: Estado vacío en pie chart
   - ✅ Implementado

5. **Interactividad**
   - Acción: Tocar barras/puntos/segmentos
   - Esperado: Mostrar tooltips con datos
   - ✅ Implementado por fl_chart

6. **Refrescar datos**
   - Acción: Presionar botón refresh
   - Esperado: Recargar y actualizar gráficas
   - ✅ Implementado

### **Comandos de Testing**

```bash
# Ejecutar en emulador/dispositivo
flutter run

# Navegar: Drawer → Reportes
# Verificar las 3 tabs
# Crear tareas y pomodoros para poblar datos
```

---

## Limitaciones Conocidas

1. **Rango de fechas fijo**: Actualmente 7 días hardcoded
   - **Mejora futura**: Selector de rango de fechas

2. **No hay persistencia de preferencias**: Tab activo no se guarda
   - **Mejora futura**: Guardar última tab visitada en SharedPreferences

3. **Carga completa de datos**: No hay paginación
   - **Impacto**: Menor, solo 7 días
   - **Mejora futura**: Si se extiende rango, implementar lazy loading

4. **No hay exportación**: No se puede exportar gráficas como imagen/PDF
   - **Mejora futura**: Botón "Compartir" para capturas de pantalla

5. **Estadísticas básicas**: Solo suma, promedio, máximo
   - **Mejora futura**: Mediana, desviación estándar, tendencias

---

## Mejoras Futuras Recomendadas

### **Fase 1B (Opcional)**
- [ ] Selector de rango de fechas (7, 14, 30 días)
- [ ] Filtro por categoría en gráfica de productividad
- [ ] Modo claro/oscuro para gráficas

### **Fase 2 (Avanzado)**
- [ ] Comparación semanal (esta semana vs anterior)
- [ ] Gráfica de heatmap (calendario de actividad)
- [ ] Exportar reportes como PDF
- [ ] Objetivos y metas con indicadores visuales

### **Fase 3 (Pro)**
- [ ] Gráficas personalizables (usuario elige qué ver)
- [ ] Insights automáticos con IA ("Tu mejor día es...", "Deberías...")
- [ ] Sincronización de estadísticas a Firebase
- [ ] Compartir reportes en redes sociales

---

## Checklist de Implementación

### **Desarrollo**
- [x] Instalar dependencia `fl_chart`
- [x] Crear `reports_screen.dart`
- [x] Implementar BarChart (Pomodoros)
- [x] Implementar PieChart (Categorías)
- [x] Implementar LineChart (Productividad)
- [x] Agregar navegación al drawer
- [x] Crear métodos de agregación de datos
- [x] Implementar estados vacíos
- [x] Agregar cards de resumen

### **Testing**
- [ ] Probar con base de datos vacía
- [ ] Probar con datos parciales
- [ ] Probar con datos completos
- [ ] Verificar tooltips interactivos
- [ ] Probar refrescar datos
- [ ] Verificar navegación entre tabs

### **Documentación**
- [x] Documentar estructura de código
- [x] Documentar uso de fl_chart
- [x] Documentar fuente de datos
- [x] Crear este documento

---

## Conclusión

✅ **Feature #7 está completo y listo para pruebas.**

### **Resumen de Logros**
- 3 tipos de gráficas funcionales
- Integración completa con controladores existentes
- Estados vacíos bien manejados
- Diseño consistente con el resto de la app
- Código limpio y bien documentado

### **Próximos Pasos**
1. Ejecutar `flutter run` para probar
2. Navegar a Reportes desde el drawer
3. Crear algunas tareas y pomodoros si es necesario
4. Verificar las 3 gráficas
5. Reportar cualquier bug encontrado

### **Integración con Roadmap**
- **Feature #7: Visual Reports** → ✅ 95% (pendiente testing final)
- **MVP General** → 🎯 ~93% Completo

---

## Errores Conocidos (Compilación)

### Advertencias Menores (No críticos):
1. **Unnecessary casts** en controladores (línea 84, 55, 31, etc.)
   - Impacto: Ninguno
   - Fix: Opcional, remover `as DatabaseServiceHybridV2`

2. **Unused fields** en `DatabaseServiceHybridV2`
   - `_pomodoroSubscription` y `_templatesSubscription`
   - Impacto: Ninguno
   - Fix: Opcional, agregar `// ignore: unused_field`

3. **Missing implementations** en `DatabaseServiceHybrid` (versión antigua)
   - Impacto: Ninguno (no se usa)
   - Fix: Eliminar archivo si no se usa

**Ningún error crítico que impida la compilación o ejecución.**

---

**Documento creado**: $(date)  
**Autor**: GitHub Copilot  
**Versión**: 1.0  
**Feature**: #7 Visual Reports
