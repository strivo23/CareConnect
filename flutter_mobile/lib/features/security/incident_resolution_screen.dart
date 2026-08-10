import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_client.dart';

class IncidentResolutionScreen extends StatefulWidget {
  final Map<String, dynamic> incidentData;

  const IncidentResolutionScreen({
    super.key,
    required this.incidentData,
  });

  @override
  State<IncidentResolutionScreen> createState() => _IncidentResolutionScreenState();
}

class _IncidentResolutionScreenState extends State<IncidentResolutionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _actionsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _casualtiesController = TextEditingController(text: '0');

  bool _med = false;
  bool _pol = false;
  bool _fire = false;
  bool _prop = false;
  bool _submitting = false;

  @override
  void dispose() {
    _summaryController.dispose();
    _actionsController.dispose();
    _notesController.dispose();
    _casualtiesController.dispose();
    super.dispose();
  }

  Future<void> _submitResolution() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Incident Resolution', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to formally resolve this emergency incident? This action will update status to RESOLVED and notify all parties.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
            child: const Text('Confirm Resolution'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      final incidentId = widget.incidentData['id'];
      await ApiClient.instance.post('/security/incidents/$incidentId/resolution/', data: {
        'resolution_summary': _summaryController.text.trim(),
        'actions_taken': _actionsController.text.trim(),
        'medical_assistance': _med,
        'police_assistance': _pol,
        'fire_assistance': _fire,
        'property_damage': _prop,
        'casualties': int.tryParse(_casualtiesController.text.trim()) ?? 0,
        'additional_notes': _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident formally resolved and closed successfully.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve incident: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Resolution #${widget.incidentData['id']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Formal Resolution Report', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Please detail actions taken and services dispatched for audit compliance.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _summaryController,
                validator: (val) => val == null || val.trim().isEmpty ? 'Resolution summary is required' : null,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Resolution Summary *',
                  hintText: 'Describe how the incident was handled and resolved...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _actionsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Actions Taken by Security Team',
                  hintText: 'Escorted medical team, controlled crowd, etc...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              Text('Services & Damage Report', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),

              CheckboxListTile(
                title: Text('Medical Assistance Dispatched', style: GoogleFonts.inter(fontSize: 13)),
                value: _med,
                onChanged: (val) => setState(() => _med = val ?? false),
              ),
              CheckboxListTile(
                title: Text('Police Officers Notified', style: GoogleFonts.inter(fontSize: 13)),
                value: _pol,
                onChanged: (val) => setState(() => _pol = val ?? false),
              ),
              CheckboxListTile(
                title: Text('Fire Brigade Dispatched', style: GoogleFonts.inter(fontSize: 13)),
                value: _fire,
                onChanged: (val) => setState(() => _fire = val ?? false),
              ),
              CheckboxListTile(
                title: Text('Property Damage Reported', style: GoogleFonts.inter(fontSize: 13)),
                value: _prop,
                onChanged: (val) => setState(() => _prop = val ?? false),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _casualtiesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Casualties / Injuries Count',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Additional Operational Notes',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitResolution,
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text('Submit Security Resolution', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
