import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../cotisations/cotisations_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();

  DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Retour éventuel d'un "join via code" effectué pendant l'inscription
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final notice = auth.joinNotice;
      if (notice != null) {
        auth.joinNoticeOk ? showSuccess(context, notice) : showError(context, notice);
        auth.clearJoinNotice();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.getDashboardStats();

      setState(() {
        _data = DashboardData.fromJson(res);
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger les données';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Ouvre le paiement de la cotisation d'une tontine depuis un rappel
  Future<void> _payer(RappelCotisation r) async {
    try {
      final res = await _api.getTontineById(r.tontineId);
      if (!mounted) return;
      final tontine = Tontine.fromJson(res['data']);
      await Navigator.push(context,
          appRoute(CotisationsScreen(tontine: tontine, openPay: true)));
      _load();
    } catch (_) {
      if (mounted) showError(context, 'Impossible d\'ouvrir le paiement');
    }
  }

  // Carte de rappel des cotisations dues ce mois-ci
  Widget _rappelCard(NumberFormat fmt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Rappel de cotisation',
                  style: soraStyle(size: 15, weight: FontWeight.w700,
                      color: Colors.white)),
              const Spacer(),
              Text('${fmt.format(_data!.montantDuMois)} FCFA',
                  style: soraStyle(size: 15, weight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 2),
          Text('À régler ce mois-ci',
              style: interStyle(size: 12, color: Colors.white70)),
          const SizedBox(height: 12),
          ..._data!.rappels.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.tontineNom,
                              style: interStyle(size: 13,
                                  weight: FontWeight.w600, color: Colors.white)),
                          Text(
                              '${fmt.format(r.montant)} FCFA${r.parts > 1 ? ' · ${r.parts} parts' : ''}',
                              style: interStyle(size: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _payer(r),
                      style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4)),
                      child: Text('Payer',
                          style: interStyle(size: 12, weight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: CustomScrollView(
          slivers: [
            // ================= HEADER =================
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.darkGradient,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                AppColors.accent.withOpacity(0.2),
                            child: Text(
                              user?.initials ?? 'U',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Bonjour 👋",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  user?.fullName ?? 'Utilisateur',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

            // ================= BODY =================
            if (_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(children: const [
                        Expanded(child: SkeletonBox(height: 118, radius: 16)),
                        SizedBox(width: 10),
                        Expanded(child: SkeletonBox(height: 118, radius: 16)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: const [
                        Expanded(child: SkeletonBox(height: 118, radius: 16)),
                        SizedBox(width: 10),
                        Expanded(child: SkeletonBox(height: 118, radius: 16)),
                      ]),
                      const SizedBox(height: 24),
                      ...List.generate(4, (_) => const SkeletonCard(height: 56)),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text("Réessayer"),
                      )
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ============ RAPPEL DE COTISATION ============
                      if ((_data?.rappels.isNotEmpty ?? false))
                        _rappelCard(fmt),

                      // ================= STATS =================
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "Tontines",
                              "${_data?.totalTontines ?? 0}",
                              Icons.group,
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              "Membres",
                              "${_data?.totalMembres ?? 0}",
                              Icons.people,
                              AppColors.success,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "Collecte",
                              "${fmt.format(_data?.totalCollecte ?? 0)}",
                              Icons.monetization_on,
                              AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              "Urgences",
                              "${_data?.urgencesEnCours ?? 0}",
                              Icons.warning,
                              AppColors.error,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ============ STATS PERSONNELLES ============
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "J'ai cotisé",
                              fmt.format(_data?.totalCotise ?? 0),
                              Icons.savings,
                              AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              "Dû ce mois",
                              fmt.format(_data?.montantDuMois ?? 0),
                              Icons.event_busy,
                              AppColors.warning,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Activités récentes",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      if ((_data?.activitesRecentes ?? []).isEmpty)
                        const Text("Aucune activité")
                      else
                        ..._data!.activitesRecentes.map(_activityCard),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Réutilise la carte stat partagée pour un rendu cohérent dans toute l'app
  Widget _statCard(String title, String value, IconData icon, Color color) =>
      StatCard(label: title, value: value, icon: icon, color: color);

  Widget _activityCard(Map<String, dynamic> a) {
    return ListTile(
      leading: const Icon(Icons.circle, size: 10),
      title: Text(a['label'] ?? '—'),
      subtitle: Text(a['tontine'] ?? ''),
      trailing: Text(
        a['created_at'] ?? '',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}