import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  final ApiService api;

  const DiagnosticsScreen({super.key, required this.api});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<DiagnosticLogItem> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getDiagnostics();
      setState(() {
        _logs = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics (LLD Sec 13)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No diagnostic logs recorded yet.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isSuccess = log.outcome == 'SUCCESS';
                    final isFailure = log.outcome == 'FAILURE';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isSuccess ? Icons.check_circle : isFailure ? Icons.error : Icons.info,
                                      size: 14,
                                      color: isSuccess ? Colors.green : isFailure ? Colors.red : Colors.cyan,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      log.eventType,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isSuccess ? Colors.green : isFailure ? Colors.redAccent : Colors.cyan,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(log.correlationId, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(log.message, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

