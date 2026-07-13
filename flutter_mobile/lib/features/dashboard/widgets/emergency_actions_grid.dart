import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/emergency_provider.dart';

class EmergencyActionsGrid extends StatelessWidget {
  const EmergencyActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = context.watch<EmergencyProvider>().quickActions;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final success = await context.read<EmergencyProvider>().triggerAction(action);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '${action.label} request sent' : 'Failed to send ${action.label} request')));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primarySoft),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(int.parse(action.colorHex.replaceFirst('#', '0xFF'))).withValues(alpha: 0.12),
                  child: Icon(_resolveIcon(action.icon), color: Color(int.parse(action.colorHex.replaceFirst('#', '0xFF')))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(action.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _resolveIcon(String name) {
    switch (name) {
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'local_police':
        return Icons.local_police_rounded;
      case 'power':
        return Icons.flash_on_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      default:
        return Icons.warning_rounded;
    }
  }
}
