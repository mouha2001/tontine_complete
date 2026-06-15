import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class CotisationsScreen extends StatefulWidget {
  final Tontine tontine;
  final bool openPay;

  const CotisationsScreen({super.key, required this.tontine, this.openPay = false});

  @override
  State<CotisationsScreen> createState() => _CotisationsScreenState();
}

class _CotisationsScreenState extends State<CotisationsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<Cotisation> _cotisations = [];
  bool _loading = true;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
    if (widget.openPay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPay());
    }
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCotisations(widget.tontine.id);
      setState(() => _cotisations = (res['data'] as List? ?? [])
          .map((j) => Cotisation.fromJson(j)).toList());
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Cotisation> get _payees    => _cotisations.where((c) => c.statut == 'confirme').toList();
  List<Cotisation> get _attente   => _cotisations.where((c) => c.statut == 'en_attente').toList();
  List<Cotisation> get _retard    => _cotisations.where((c) => c.statut == 'echoue').toList();

  void _showPay() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaySheet(
      tontine: widget.tontine,
      onDone: () { Navigator.pop(context); _load(); },
    ),
  );

  Future<void> _confirm(Cotisation c) async {
    try {
      await _api.confirmerCotisation(c.id);
      if (mounted) showSuccess(context, 'Cotisation confirmée');
      _load();
    } catch (_) {
      if (mounted) showError(context, 'Action impossible');
    }
  }

  Future<void> _reject(Cotisation c) async {
    try {
      await _api.rejeterCotisation(c.id);
      if (mounted) showSuccess(context, 'Cotisation rejetée');
      _load();
    } catch (_) {
      if (mounted) showError(context, 'Action impossible');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final totalPayees = _payees.fold(0.0, (s, c) => s + c.montant);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.tontine.nom),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.accent,
          tabs: [
            Tab(text: 'Confirmées (${_payees.length})'),
            Tab(text: 'En attente (${_attente.length})'),
            Tab(text: 'Rejetées (${_retard.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Bannière résumé ───────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total collecté',
                          style: interStyle(size: 12, color: Colors.white70)),
                      Text('${fmt.format(totalPayees)} FCFA',
                          style: soraStyle(size: 20, weight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Par tour',
                        style: interStyle(size: 12, color: Colors.white70)),
                    Text('${fmt.format(widget.tontine.montantCotisation)} FCFA',
                        style: interStyle(size: 14, weight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),

          // ── Tabs ──────────────────────────────────────
          Expanded(
            child: _loading
                ? const FullScreenLoader()
                : TabBarView(
                    controller: _tab,
                    children: [
                      _CotList(cotisations: _payees,
                          empty: 'Aucune cotisation confirmée'),
                      _CotList(cotisations: _attente,
                          empty: 'Aucune cotisation en attente',
                          isAdmin: widget.tontine.estAdmin,
                          onConfirm: _confirm, onReject: _reject),
                      _CotList(cotisations: _retard,
                          empty: 'Aucune cotisation rejetée'),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: PrimaryButton(
            label: 'Payer ma cotisation',
            onPressed: _showPay,
            icon: Icons.payment_rounded,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  LISTE COTISATIONS
// ─────────────────────────────────────────────────────────
class _CotList extends StatelessWidget {
  final List<Cotisation> cotisations;
  final String empty;
  final bool isAdmin;
  final Future<void> Function(Cotisation)? onConfirm;
  final Future<void> Function(Cotisation)? onReject;
  const _CotList({required this.cotisations, required this.empty,
      this.isAdmin = false, this.onConfirm, this.onReject});

  @override
  Widget build(BuildContext context) {
    if (cotisations.isEmpty) {
      return EmptyState(icon: Icons.receipt_long_outlined, message: empty);
    }
    final fmt = NumberFormat('#,###', 'fr_FR');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: cotisations.length,
      itemBuilder: (_, i) {
        final c = cotisations[i];
        final showActions = isAdmin && c.statut == 'en_attente'
            && onConfirm != null && onReject != null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(c.icon, color: c.color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.userName ?? 'Membre',
                            style: interStyle(size: 13, weight: FontWeight.w600,
                                color: AppColors.textDark)),
                        if (c.periodeLabel != null)
                          Text(c.periodeLabel!,
                              style: interStyle(size: 12,
                                  weight: FontWeight.w600, color: AppColors.accent)),
                        if (c.datePaiement != null)
                          Text(DateFormat('dd/MM/yyyy').format(c.datePaiement!),
                              style: interStyle(size: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${fmt.format(c.montant)} FCFA',
                          style: interStyle(size: 13, weight: FontWeight.w700,
                              color: c.color)),
                      StatusBadge(label: c.statutLabel, color: c.color),
                    ],
                  ),
                ],
              ),
              if (showActions) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onReject!(c),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error)),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Rejeter'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onConfirm!(c),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Confirmer'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  SHEET : PAYER
// ─────────────────────────────────────────────────────────
class _PaySheet extends StatefulWidget {
  final Tontine tontine;
  final VoidCallback onDone;
  const _PaySheet({required this.tontine, required this.onDone});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  final _api    = ApiService();
  final _refCtrl = TextEditingController();
  String _methode = 'wave';
  bool _loading   = false;

  // 'now' capturé une seule fois → la période sélectionnée reste toujours
  // l'une des options proposées (même si la feuille reste ouverte à travers minuit).
  final DateTime _now = DateTime.now();
  late final List<DateTime> _moisOptions =
      List.generate(4, (i) => DateTime(_now.year, _now.month + i, 1));
  late DateTime _periode = _moisOptions.first;

  int get _mesParts => widget.tontine.mesParts > 0 ? widget.tontine.mesParts : 1;
  double get _montantDu => widget.tontine.montantCotisation * _mesParts;

  static const _methodes = [
    {'value': 'wave',         'label': 'Wave',         'icon': Icons.waves_rounded},
    {'value': 'orange_money', 'label': 'Orange Money', 'icon': Icons.phone_android_rounded},
    {'value': 'free_money',   'label': 'Free Money',   'icon': Icons.attach_money_rounded},
    {'value': 'cash',         'label': 'Cash',         'icon': Icons.payments_rounded},
  ];

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      await _api.payerCotisation(widget.tontine.id, {
        'montant': _montantDu,
        'methode_paiement': _methode,
        'reference': _refCtrl.text.trim(),
        'periode': '${_periode.year.toString().padLeft(4, '0')}'
            '-${_periode.month.toString().padLeft(2, '0')}-01',
      });
      if (!mounted) return;
      showSuccess(context, 'Cotisation enregistrée, en attente de validation');
      widget.onDone();
    } catch (_) {
      if (mounted) showError(context, 'Erreur lors du paiement');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('Payer ma cotisation',
                style: soraStyle(size: 20, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: interStyle(size: 14),
                children: [
                  const TextSpan(text: 'Montant : '),
                  TextSpan(
                    text: '${fmt.format(_montantDu)} FCFA',
                    style: interStyle(size: 15, weight: FontWeight.w700,
                        color: AppColors.accent),
                  ),
                  if (_mesParts > 1)
                    TextSpan(
                      text: '  ($_mesParts parts × ${fmt.format(widget.tontine.montantCotisation)})',
                      style: interStyle(size: 12, color: AppColors.textLight),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Mois concerné',
                style: interStyle(size: 13, weight: FontWeight.w600,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('Vous pouvez payer à l\'avance pour un mois à venir.',
                style: interStyle(size: 11, color: AppColors.textLight)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _moisOptions.map((m) {
                final sel = m.year == _periode.year && m.month == _periode.month;
                final now = DateTime.now();
                final isCurrent = m.year == now.year && m.month == now.month;
                return GestureDetector(
                  onTap: () => setState(() => _periode = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.accent : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? AppColors.accent : AppColors.border),
                    ),
                    child: Text(isCurrent ? '${moisAnnee(m)} (ce mois)' : moisAnnee(m),
                        style: interStyle(size: 12, weight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textGrey)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Méthode de paiement',
                style: interStyle(size: 13, weight: FontWeight.w600,
                    color: AppColors.textDark)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _methodes.map((m) {
                final sel = m['value'] == _methode;
                return GestureDetector(
                  onTap: () => setState(() => _methode = m['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(m['icon'] as IconData, size: 16,
                            color: sel ? Colors.white : AppColors.textGrey),
                        const SizedBox(width: 6),
                        Text(m['label'] as String,
                            style: interStyle(size: 13, weight: FontWeight.w600,
                                color: sel ? Colors.white : AppColors.textGrey)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            AppField(controller: _refCtrl, label: 'Référence transaction (optionnel)',
                hint: 'Ex: TXN123456', prefixIcon: Icons.receipt_long_outlined),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Confirmer le paiement',
                onPressed: _pay, loading: _loading),
          ],
        ),
      ),
    );
  }
}