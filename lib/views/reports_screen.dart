import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/pomodoro_controller.dart';
import '../controllers/task_controller.dart';
import '../models/pomodoro_session.dart';
import '../models/task.dart';
import '../models/category.dart' as model;
import '../widgets/app_drawer.dart';

/// Pantalla de reportes visuales con gráficas
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    final taskController = Provider.of<TaskController>(context, listen: false);
    
    // Cargar/refrescar datos
    await taskController.refresh();
    
    // Las sesiones de Pomodoro se cargan automáticamente en el constructor
    // del PomodoroController, por lo que no necesitamos llamar métodos aquí
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Estadísticas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Pomodoros'),
            Tab(icon: Icon(Icons.pie_chart), text: 'Categorías'),
            Tab(icon: Icon(Icons.show_chart), text: 'Tendencia'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'reports'),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPomodorosBarChart(),
          _buildCategoriesPieChart(),
          _buildProductivityLineChart(),
        ],
      ),
    );
  }

  /// Gráfica de barras: Pomodoros por día (últimos 7 días)
  Widget _buildPomodorosBarChart() {
    return Consumer<PomodoroController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Preparar datos de los últimos 7 días
        final data = _getPomodorosPerDay(controller.sessions, 7);
        
        if (data.isEmpty || data.values.every((v) => v == 0)) {
          return _buildEmptyState(
            'Sin datos de Pomodoro',
            'Completa algunas sesiones de trabajo para ver estadísticas.',
            Icons.timer_off,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen
              _buildSummaryCard(
                title: 'Últimos 7 días',
                stats: [
                  _StatItem(
                    label: 'Total Pomodoros',
                    value: data.values.reduce((a, b) => a + b).toString(),
                    icon: Icons.local_fire_department,
                    color: Colors.red,
                  ),
                  _StatItem(
                    label: 'Promedio/día',
                    value: (data.values.reduce((a, b) => a + b) / 7).toStringAsFixed(1),
                    icon: Icons.trending_up,
                    color: Colors.blue,
                  ),
                  _StatItem(
                    label: 'Mejor día',
                    value: data.values.reduce((a, b) => a > b ? a : b).toString(),
                    icon: Icons.star,
                    color: Colors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Gráfica
              Text(
                'Pomodoros por Día',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (data.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final dayName = _getDayName(6 - groupIndex);
                          return BarTooltipItem(
                            '$dayName\n${rod.toY.round()} 🍅',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _getDayNameShort(6 - value.toInt()),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data.entries.map((entry) {
                      final index = data.keys.toList().indexOf(entry.key);
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.toDouble(),
                            color: Colors.red.shade400,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            gradient: LinearGradient(
                              colors: [Colors.red.shade300, Colors.red.shade600],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Gráfica de pastel: Tareas por categoría
  Widget _buildCategoriesPieChart() {
    return Consumer<TaskController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Contar tareas por categoría
        final tasksByCategory = <String, int>{};
        final categoriesMap = <String, model.Category>{};
        
        for (var category in controller.categories) {
          categoriesMap[category.id] = category;
          tasksByCategory[category.id] = 0;
        }
        
        for (var task in controller.tasks) {
          if (task.status == TaskStatus.pending) {
            tasksByCategory[task.category] = (tasksByCategory[task.category] ?? 0) + 1;
          }
        }
        
        // Filtrar categorías con tareas
        tasksByCategory.removeWhere((key, value) => value == 0);
        
        if (tasksByCategory.isEmpty) {
          return _buildEmptyState(
            'Sin tareas pendientes',
            'Crea algunas tareas para ver la distribución por categorías.',
            Icons.category_outlined,
          );
        }

        final totalTasks = tasksByCategory.values.reduce((a, b) => a + b);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen
              _buildSummaryCard(
                title: 'Tareas Pendientes',
                stats: [
                  _StatItem(
                    label: 'Total',
                    value: totalTasks.toString(),
                    icon: Icons.assignment,
                    color: Colors.blue,
                  ),
                  _StatItem(
                    label: 'Categorías activas',
                    value: tasksByCategory.length.toString(),
                    icon: Icons.category,
                    color: Colors.purple,
                  ),
                  _StatItem(
                    label: 'Más tareas',
                    value: categoriesMap[tasksByCategory.entries.reduce((a, b) => a.value > b.value ? a : b).key]?.name ?? '-',
                    icon: Icons.trending_up,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Gráfica
              Text(
                'Distribución por Categoría',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                height: 300,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: tasksByCategory.entries.map((entry) {
                      final category = categoriesMap[entry.key];
                      final percentage = (entry.value / totalTasks * 100);
                      
                      return PieChartSectionData(
                        color: category?.color ?? Colors.grey,
                        value: entry.value.toDouble(),
                        title: '${percentage.toStringAsFixed(0)}%',
                        radius: 100,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        badgeWidget: _buildBadge(
                          category?.icon ?? Icons.folder,
                          category?.color ?? Colors.grey,
                        ),
                        badgePositionPercentageOffset: 1.5,
                      );
                    }).toList(),
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Leyenda
              ...tasksByCategory.entries.map((entry) {
                final category = categoriesMap[entry.key];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: category?.color ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(category?.icon ?? Icons.folder, size: 20, color: category?.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category?.name ?? 'Desconocida',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${entry.value} tarea${entry.value > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Gráfica de línea: Tendencia de productividad
  Widget _buildProductivityLineChart() {
    return Consumer<PomodoroController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Calcular minutos productivos por día
        final data = _getProductivityPerDay(controller.sessions, 7);
        
        if (data.isEmpty || data.values.every((v) => v == 0)) {
          return _buildEmptyState(
            'Sin datos de productividad',
            'Completa sesiones de Pomodoro para ver tu tendencia.',
            Icons.show_chart,
          );
        }

        final maxMinutes = data.values.reduce((a, b) => a > b ? a : b);
        final totalMinutes = data.values.reduce((a, b) => a + b);
        final avgMinutes = totalMinutes / 7;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen
              _buildSummaryCard(
                title: 'Productividad Semanal',
                stats: [
                  _StatItem(
                    label: 'Total minutos',
                    value: '$totalMinutes min',
                    icon: Icons.timer,
                    color: Colors.green,
                  ),
                  _StatItem(
                    label: 'Promedio/día',
                    value: '${avgMinutes.toStringAsFixed(0)} min',
                    icon: Icons.av_timer,
                    color: Colors.blue,
                  ),
                  _StatItem(
                    label: 'Mejor día',
                    value: '$maxMinutes min',
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Gráfica
              Text(
                'Tendencia de Productividad',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Minutos de trabajo efectivo por día',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                height: 300,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: (maxMinutes + 20).toDouble(),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final dayName = _getDayName(spot.x.toInt());
                            return LineTooltipItem(
                              '$dayName\n${spot.y.toInt()} min',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _getDayNameShort(value.toInt()),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}m',
                              style: const TextStyle(fontSize: 11),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.entries.map((entry) {
                          final index = data.keys.toList().indexOf(entry.key);
                          return FlSpot(index.toDouble(), entry.value.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: Colors.green,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.3),
                              Colors.green.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Línea de promedio
                      LineChartBarData(
                        spots: List.generate(
                          7,
                          (index) => FlSpot(index.toDouble(), avgMinutes),
                        ),
                        isCurved: false,
                        color: Colors.blue.withOpacity(0.5),
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Productividad', Colors.green),
                  const SizedBox(width: 24),
                  _buildLegendItem('Promedio', Colors.blue.withOpacity(0.5)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Helper: Obtener pomodoros por día
  Map<String, int> _getPomodorosPerDay(List<PomodoroSession> sessions, int days) {
    final data = <String, int>{};
    final now = DateTime.now();
    
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _formatDate(date);
      data[key] = 0;
    }
    
    for (var session in sessions) {
      if (session.sessionType == SessionType.work && session.isCompleted) {
        final key = _formatDate(session.startTime);
        if (data.containsKey(key)) {
          data[key] = (data[key] ?? 0) + 1;
        }
      }
    }
    
    return data;
  }

  /// Helper: Obtener minutos productivos por día
  Map<String, int> _getProductivityPerDay(List<PomodoroSession> sessions, int days) {
    final data = <String, int>{};
    final now = DateTime.now();
    
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _formatDate(date);
      data[key] = 0;
    }
    
    for (var session in sessions) {
      if (session.sessionType == SessionType.work && session.isCompleted) {
        final key = _formatDate(session.startTime);
        if (data.containsKey(key)) {
          data[key] = (data[key] ?? 0) + session.durationInMinutes;
        }
      }
    }
    
    return data;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getDayName(int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: 6 - daysAgo));
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[date.weekday - 1];
  }

  String _getDayNameShort(int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: 6 - daysAgo));
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return days[date.weekday - 1];
  }

  Widget _buildSummaryCard({
    required String title,
    required List<_StatItem> stats,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: stats.map((stat) => Expanded(
                child: Column(
                  children: [
                    Icon(stat.icon, color: stat.color, size: 24),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        stat.value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: stat.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
