import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<AppNotification> _notifs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getNotifications();
      setState(() => _notifs = (res['data'] as List? ?? [])
          .map((j) => AppNotification.fromJson(j)).toList());
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.lue) return;
    try {
      await _api.markNotificationRead(n.id);
      setState(() {
        final i = _notifs.indexWhere((x) => x.id == n.id);
        if (i != -1) {
          _notifs[i] = AppNotification(
            id: n.id, titre: n.titre, message: n.message,
            type: n.type, lue: true, createdAt: n.createdAt,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    for (final n in _notifs.where((x) => !x.lue).toList()) {
      await _markRead(n);
    }
  }

  int get _unread => _notifs.where((n) => !n.lue).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_unread',
                    style: interStyle(size: 11, weight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Tout lire',
                  style: interStyle(size: 13, weight: FontWeight.w600,
                      color: AppColors.accent)),
            ),
        ],
      ),
      body: _loading
          ? const FullScreenLoader()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: _notifs.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      message: 'Aucune notification',
                      subMessage: 'Vous serez notifié des activités importantes',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifs.length,
                      itemBuilder: (_, i) => _NotifCard(
                        notif: _notifs[i],
                        onTap: _markRead,
                      ),
                    ),
            ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final Future<void> Function(AppNotification) onTap;
  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(notif),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.lue ? AppColors.white : AppColors.accent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.lue ? AppColors.border : AppColors.accent.withOpacity(0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: notif.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(notif.icon, color: notif.color, size: 18),
            ),
            const SizedBox(width: 12),
            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.titre,
                            style: interStyle(size: 13,
                                weight: notif.lue ? FontWeight.w500 : FontWeight.w700,
                                color: AppColors.textDark)),
                      ),
                      if (!notif.lue)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.message, style: interStyle(size: 12)),
                  if (notif.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(_timeAgo(notif.createdAt!),
                        style: interStyle(size: 11, color: AppColors.textLight)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7)     return 'Il y a ${diff.inDays}j';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}