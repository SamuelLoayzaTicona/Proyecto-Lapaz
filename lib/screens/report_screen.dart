import 'package:flutter/material.dart';
import '../data/pilot_zone_data.dart';
import '../models/transport_models.dart';
import '../services/report_repository.dart';

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
  bool _isSubmitting = false;

  /// Lista de sindicatos a mostrar. El planificador de rutas a veces manda
  /// valores que no están en la lista fija de PilotZoneData (ej. "Por
  /// confirmar", "Cualquier sindicato"), y el DropdownButtonFormField de
  /// Flutter truena si el valor seleccionado no está EXACTAMENTE entre sus
  /// opciones. Por eso agregamos aquí cualquier valor prellenado que falte.
  late final List<String> _syndicateOptions = [
    if (widget.prefilledSyndicate != null &&
        widget.prefilledSyndicate!.trim().isNotEmpty &&
        !PilotZoneData.syndicates.contains(widget.prefilledSyndicate))
      widget.prefilledSyndicate!,
    ...PilotZoneData.syndicates,
  ];

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

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe brevemente lo que pasó.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ReportRepository.instance.submitReport(
        TrameajeReport(
          syndicate: _selectedSyndicate ?? 'Desconocido',
          plate: _plateController.text.trim(),
          description: _descriptionController.text.trim(),
          reportedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu reporte ha sido recibido. La unidad de transparencia lo revisará en 48 horas.'),
        ),
      );
      _plateController.clear();
      _descriptionController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el reporte: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
              'Tu reporte queda guardado y visible para el seguimiento de la Alcaldía.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedSyndicate,
              decoration: const InputDecoration(labelText: 'Sindicato'),
              items: _syndicateOptions
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
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Enviando...' : 'Enviar reporte'),
            ),
            const SizedBox(height: 24),
            Text('Reportes recientes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            StreamBuilder<List<TrameajeReport>>(
              stream: ReportRepository.instance.watchReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No se pudieron cargar los reportes. Revisa tu conexión a Firebase.\n${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Todavía no hay reportes.', style: TextStyle(color: Colors.black54)),
                  );
                }
                return Column(
                  children: reports.map((r) => _ReportTile(report: r)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final TrameajeReport report;
  const _ReportTile({required this.report});

  Color _statusColor(String status) {
    switch (status) {
      case 'En revisión':
        return Colors.orange;
      case 'Atendido':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(report.syndicate),
        subtitle: Text(report.description),
        trailing: Chip(
          label: Text(report.status, style: const TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: _statusColor(report.status),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
