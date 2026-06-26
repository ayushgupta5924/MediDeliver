import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.medical_services_rounded,
                size: 80,
                color: Color(0xFF00897B),
              ),
              const SizedBox(height: 16),
              const Text(
                'MediDeliver',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Medicine • Delivered in 60 minutes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 64),

              _RoleButton(
                icon: Icons.person_outline,
                title: 'I need medicine',
                subtitle: 'Order & upload prescription',
                color: const Color(0xFF00897B),
                onTap: () => context.go('/patient'),
              ),
              const SizedBox(height: 16),

              _RoleButton(
                icon: Icons.local_pharmacy_outlined,
                title: 'I am a Pharmacist',
                subtitle: 'Review & approve orders',
                color: const Color(0xFF1565C0),
                onTap: () => context.go('/pharmacist'),
              ),
              const SizedBox(height: 16),

              _RoleButton(
                icon: Icons.delivery_dining_outlined,
                title: 'I am a Delivery Partner',
                subtitle: 'Accept & deliver orders',
                color: const Color(0xFFE65100),
                onTap: () => context.go('/rider'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
