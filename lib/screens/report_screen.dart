import 'package:flutter/material.dart';
import '../data/pilot_zone_data.dart';
import '../models/transport_models.dart';

class ReportScreen extends StatefulWidget {
  final String? prefilledSyndicate;
  const ReportScreen({super.key, this.prefilledSyndicate});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedSyndicate;
  final _plateController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Almacenamiento en memoria para la demo (sin backend todavía).
  static final List<TrameajeReport> _localReports = [];

  @override
  void initState() {
    super.initState();
    _selectedSyndicate = widget.prefilledSyndicate ?? PilotZoneData.syndicates.first;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe brevemente lo que pasó.')),
      );
      return;
    }
    setState(() {
      _localReports.add(TrameajeReport(
        syndicate: _selectedSyndicate ?? 'Desconocido',
        plate: _plateController.text.trim(),
        description: _descriptionController.text.trim(),
        reportedAt: DateTime.now(),
      ));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gracias. Tu reporte ayuda a ordenar el transporte.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar trameaje')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              'Ayúdanos a identificar minibuses que no cumplen su ruta o tarifa autorizada. '
              'Tu reporte queda anónimo para la Alcaldía.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedSyndicate,
              decoration: const InputDecoration(labelText: 'Sindicato'),
              items: PilotZoneData.syndicates
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSyndicate = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(labelText: 'Placa (opcional)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej: Se desvió por la Av. X en vez de seguir la ruta oficial.',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar reporte'),
            ),
            if (_localReports.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Reportes en esta sesión (${_localReports.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._localReports.reversed.map(
                (r) => Card(
                  child: ListTile(
                    title: Text(r.syndicate),
                    subtitle: Text(r.description),
                    trailing: Text(
                      '${r.reportedAt.hour}:${r.reportedAt.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
