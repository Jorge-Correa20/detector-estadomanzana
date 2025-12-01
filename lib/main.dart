// main.dart COMPLETO Y CORREGIDO
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard Clasificador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const AppleStatsDashboard(),
    );
  }
}

class AppleStatsDashboard extends StatefulWidget {
  const AppleStatsDashboard({super.key});

  @override
  State<AppleStatsDashboard> createState() => _AppleStatsDashboardState();
}

class _AppleStatsDashboardState extends State<AppleStatsDashboard> {
  // --- TU URL DE AWS ---
  final String _statsApiUrl = "https://f5278inwic.execute-api.us-east-2.amazonaws.com/dev/stats";

  int _totalCount = 0;
  Map<String, int> _counts = {};
  bool _isLoading = true;
  Timer? _timer;
  String _errorMessage = ""; // Para ver errores en pantalla si ocurren

  @override
  void initState() {
    super.initState();
    _fetchStatsFromAWS();
    // Refresco cada 3 segundos
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchStatsFromAWS();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- FUNCIÓN BLINDADA CONTRA ERRORES ---
  Future<void> _fetchStatsFromAWS() async {
    try {
      print("Conectando a AWS..."); 
      final response = await http.get(Uri.parse(_statsApiUrl));

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        print("Datos recibidos: $payload"); // MIRA ESTO EN LA CONSOLA F12

        setState(() {
          _totalCount = payload['total_items'] ?? 0;
          
          Map<String, dynamic> rawCounts = payload['classification_counts'] ?? {};
          _counts = {};

          // CONVERSIÓN SEGURA (Aquí estaba el error antes)
          rawCounts.forEach((key, value) {
            // Convertimos a String y luego a Int para evitar errores de tipo en Web
            _counts[key] = int.parse(value.toString());
          });
          
          _isLoading = false;
          _errorMessage = "";
        });
      } else {
        setState(() {
          _errorMessage = "Error AWS: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("ERROR CRÍTICO: $e");
      setState(() {
        // Esto te mostrará el error en la pantalla del celular/web
        _errorMessage = "Error: $e"; 
        _isLoading = false;
      });
    }
  }

  MaterialColor get _baseEmphasisColor {
    if (_totalCount == 0) return Colors.grey;
    // Buscamos 'Mal Estado' o variantes
    int badCount = _counts['Mal Estado'] ?? _counts['Bad'] ?? 0;
    double spoiledPercent = badCount / _totalCount;

    if (spoiledPercent > 0.10) return Colors.red;
    if (spoiledPercent > 0.03) return Colors.orange;
    return Colors.green;
  }

  Color get _emphasisColor => _baseEmphasisColor.shade700;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Frutas (AWS)'),
        backgroundColor: _emphasisColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStatsFromAWS,
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
                  // Muestra error si existe
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.red.shade100,
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                    ),
                    
                  _buildTotalCard(),
                  const SizedBox(height: 20),
                  _buildClassificationCard('Buen Estado', Colors.green),
                  const SizedBox(height: 15),
                  _buildClassificationCard('Mal Estado', Colors.red),
                  const SizedBox(height: 15),
                  Text(
                    'Última actualización: ${DateTime.now().toString().split('.')[0]}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [_emphasisColor, _baseEmphasisColor.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text('TOTAL PROCESADAS', style: TextStyle(color: Colors.white70)),
            Text(
              _totalCount.toString(),
              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationCard(String label, MaterialColor color) {
    final count = _counts[label] ?? 0;
    final percentage = _totalCount > 0 ? (count / _totalCount) * 100 : 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.shade800)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(count.toString(), style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color.shade700)),
                Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(color: color.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}