import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.darkGradient),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Avatar
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.accent.withOpacity(0.2),
                      child: Text(
                        user?.initials ?? 'U',
                        style: soraStyle(size: 32, weight: FontWeight.w700,
                            color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(user?.fullName ?? '—',
                        style: soraStyle(size: 20, weight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(user?.telephone ?? '',
                        style: interStyle(size: 14, color: Colors.white60)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informations personnelles',
                      style: soraStyle(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  _InfoTile(Icons.person_outline, 'Nom complet',
                      user?.fullName ?? '—'),
                  _InfoTile(Icons.phone_outlined, 'Téléphone',
                      user?.telephone ?? '—'),
                  if (user?.email != null)
                    _InfoTile(Icons.email_outlined, 'Email', user!.email!),
                  _InfoTile(Icons.badge_outlined, 'Rôle',
                      user?.role == 'admin' ? '★ Administrateur' : 'Membre'),

                  const SizedBox(height: 32),

                  // Déconnexion
                  OutlinedButton.icon(
                    onPressed: () async {
                      // Confirmation
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: Text('Déconnexion',
                              style: soraStyle(size: 18)),
                          content: Text('Voulez-vous vraiment vous déconnecter ?',
                              style: interStyle(size: 14)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error),
                              child: const Text('Déconnecter'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded,
                        size: 18, color: AppColors.error),
                    label: Text('Se déconnecter',
                        style: interStyle(size: 15, weight: FontWeight.w600,
                            color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textLight),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: interStyle(size: 11)),
            Text(value, style: interStyle(size: 14, weight: FontWeight.w600,
                color: AppColors.textDark)),
          ],
        ),
      ],
    ),
  );
}