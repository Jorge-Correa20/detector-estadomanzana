// El paquete HTTP es necesario para las llamadas API
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Definimos los posibles estados (se usan como claves en el JSON)
enum AppleCondition {
  good, // Buen estado
  spoiled, // Mal estado
  unknown // Estado inicial o error
}

void main() {
  runApp(const MyApp());
}

// ----------------------------------------------------
// 1. Estructura Base de la Aplicación (Widget Raíz)
// ----------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard Clasificador de Frutas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green, 
        useMaterial3: true,
      ),
      home: const AppleStatsDashboard(), 
    );
  }
}

// ----------------------------------------------------
// 2. Dashboard de Estadísticas (StatefulWidget)
// ----------------------------------------------------
class AppleStatsDashboard extends StatefulWidget {
  const AppleStatsDashboard({super.key});

  @override
  State<AppleStatsDashboard> createState() => _AppleStatsDashboardState();
}

class _AppleStatsDashboardState extends State<AppleStatsDashboard> {
  // --- CONFIGURACIÓN AWS (REEMPLAZAR) ---
  // ¡IMPORTANTE! Reemplaza esto con la URL de salida 'StatsApiUrl' de CloudFormation
  final String _statsApiUrl = "https://f5278inwic.execute-api.us-east-2.amazonaws.com/dev/stats";

  // Variables de Estado (Contadores leídos de DynamoDB)
  int _totalCount = 0;
  Map<String, int> _counts = {
    'Buen Estado': 0,
    'Mal Estado': 0,
    'UNKNOWN': 0
  };
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Inicia la primera carga de datos
    _fetchStatsFromAWS();
    // Configura un temporizador para refrescar los datos cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchStatsFromAWS();
    });
  }

  @override
  void dispose() {
    // Detiene el temporizador cuando el widget es destruido
    _timer?.cancel();
    super.dispose();
  }

  // --- LÓGICA DE CONEXIÓN HTTP A AWS ---
  Future<void> _fetchStatsFromAWS() async {
    try {
      final response = await http.get(Uri.parse(_statsApiUrl));

      if (response.statusCode == 200) {
        // La Lambda devuelve el cuerpo como una cadena JSON, por eso usamos jsonDecode
        //final data = jsonDecode(response.body); 
        // El cuerpo real es una cadena JSON dentro de otra cadena JSON debido a la integración proxy de Lambda/API Gateway
        final payload = jsonDecode(response.body);


        setState(() {
          _totalCount = payload['total_items'] ?? 0;
          // Conversión segura del Map
          final rawCounts = payload['classification_counts'] as Map<String, dynamic>?; 
          _counts = rawCounts?.map((k, v) => MapEntry(k, v as int)) ?? {};
          _isLoading = false;
        });

      } else {
        throw Exception('Fallo la carga de estadísticas. Código: ${response.statusCode}');
      }
    } catch (e) {
      // Solución a los errores de 'void' y 'not_enough_positional_arguments'.
      // debugPrint registra el error.
      debugPrint('Error al conectar con AWS o parsear datos: $e'); 
      // setState actualiza la UI.
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Lógica para determinar el COLOR BASE (MaterialColor) para el énfasis
  MaterialColor get _baseEmphasisColor {
    if (_totalCount == 0) return Colors.grey;
    
    double spoiledPercent = (_counts['Mal Estado'] ?? 0) / _totalCount;

    if (spoiledPercent > 0.10) {
      return Colors.red; // Retorna la familia de color MaterialColor
    } else if (spoiledPercent > 0.03) {
      return Colors.orange; // Retorna la familia de color MaterialColor
    } else {
      return Colors.green; // Retorna la familia de color MaterialColor
    }
  }

  // Lógica para determinar el color de énfasis (SHADE 700 para el AppBar/Tarjeta principal)
  Color get _emphasisColor {
    return _baseEmphasisColor.shade700;
  }

  // ----------------------------------------------------
  // 3. Diseño del Dashboard
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Usa el shade 700 para el AppBar
        title: const Text('Dashboard de Clasificación (AWS Live)'),
        backgroundColor: _emphasisColor, 
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStatsFromAWS, // Refresca manualmente
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Tarjeta de Resumen Total
                  _buildTotalCard(),
                  const SizedBox(height: 20),
                  
                  // Tarjetas de Clasificación
                  _buildClassificationCard('Buen Estado', Colors.green),
                  const SizedBox(height: 15),
                  _buildClassificationCard('Mal Estado', Colors.red),
                  const SizedBox(height: 15),
                  
                  // Información de Conexión
                  Text(
                    'Última actualización: ${DateTime.now().toLocal().toString().substring(11, 19)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
    );
  }

  // Widget para la tarjeta de resumen total
  Widget _buildTotalCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              _emphasisColor, // Usa el shade 700
              // Accede a shade500 desde _baseEmphasisColor (MaterialColor)
              _baseEmphasisColor.shade500, 
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text(
              'TOTAL DE FRUTAS PROCESADAS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _totalCount.toString(),
              style: const TextStyle(
                fontSize: 70,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para las tarjetas individuales de clasificación
  Widget _buildClassificationCard(String label, MaterialColor color) {
    final count = _counts[label] ?? 0;
    final percentage = _totalCount > 0 ? (count / _totalCount) * 100 : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color.shade800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Porcentaje del total',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: color.shade700,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}