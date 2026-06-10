import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// ─────────────────────────────────────────────────────────
//  SUTURA — Demandes d'urgence (anonymes) + vote anonyme
// ─────────────────────────────────────────────────────────
class SuturaScreen extends StatefulWidget {
  final Tontine tontine;
  const SuturaScreen({super.key, required this.tontine});

  @override
  State<SuturaScreen> createState() => _SuturaScreenState();
}

class _SuturaScreenState extends State<SuturaScreen> {
  final _api = ApiService();
  List<Sutura> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSuturas(widget.tontine.id);
      setState(() => _items = (res['data'] as List? ?? [])
          .map((j) => Sutura.fromJson(j)).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vote(Sutura s, bool approuve) async {
    try {
      await _api.voterSutura(s.id, approuve);
      if (mounted) showSuccess(context, 'Vote enregistré');
      await _load();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response?.data['message'] as String?
          : null;
      if (mounted) showError(context, msg ?? 'Vote impossible');
    }
  }

  void _newRequest() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NewSuturaSheet(
          tontine: widget.tontine,
          onDone: () { Navigator.pop(context); _load(); },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Demandes d\'urgence')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Demander'),
      ),
      body: Column(
        children: [
          // Bandeau anonymat
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Demandes et votes 100 % anonymes : personne ne voit qui a demandé, ni qui a voté quoi.',
                    style: interStyle(size: 12, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const FullScreenLoader()
                : _items.isEmpty
                    ? const EmptyState(
                        icon: Icons.health_and_safety_outlined,
                        message: 'Aucune demande d\'urgence',
                        subMessage: 'Lancez une demande si vous avez besoin des fonds en urgence')
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: _items.length,
                          itemBuilder: (_, i) =>
                              _SuturaCard(key: ValueKey(_items[i].id),
                                  sutura: _items[i], onVote: _vote,
                                  onExpired: _load),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  CARTE D'UNE DEMANDE
// ─────────────────────────────────────────────────────────
class _SuturaCard extends StatefulWidget {
  final Sutura sutura;
  final Future<void> Function(Sutura, bool) onVote;
  final Future<void> Function() onExpired;
  const _SuturaCard({super.key, required this.sutura, required this.onVote, required this.onExpired});

  @override
  State<_SuturaCard> createState() => _SuturaCardState();
}

class _SuturaCardState extends State<_SuturaCard> {
  Timer? _timer;
  bool _firedExpired = false;

  @override
  void initState() {
    super.initState();
    _setupTimer();
  }

  @override
  void didUpdateWidget(_SuturaCard old) {
    super.didUpdateWidget(old);
    final s = widget.sutura, o = old.sutura;
    if (o.id != s.id || o.statut != s.statut || o.voteExpiresAt != s.voteExpiresAt) {
      _firedExpired = false;
      _setupTimer();
    }
  }

  // (Re)met en place le compte à rebours selon l'état courant de l'urgence
  void _setupTimer() {
    _timer?.cancel();
    _timer = null;
    final s = widget.sutura;
    if (s.statut == 'en_cours' && s.voteExpiresAt != null && !s.expire) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (widget.sutura.expire) {
          _timer?.cancel();
          // Force la résolution côté serveur via un rechargement (une seule fois)
          if (!_firedExpired) { _firedExpired = true; widget.onExpired(); }
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final s = widget.sutura;
    final showCountdown = s.statut == 'en_cours' && s.voteExpiresAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${fmt.format(s.montantDemande)} FCFA',
                    style: soraStyle(size: 18, weight: FontWeight.w700)),
              ),
              StatusBadge(label: s.statutLabel, color: s.statutColor),
            ],
          ),
          if (showCountdown) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14,
                    color: s.expire ? AppColors.error : AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  s.expire ? 'Temps écoulé' : 'Temps restant : ${_fmt(s.tempsRestant)}',
                  style: interStyle(size: 12, weight: FontWeight.w600,
                      color: s.expire ? AppColors.error : AppColors.warning),
                ),
              ],
            ),
          ],
          if (s.estMien) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Votre demande',
                  style: interStyle(size: 11, weight: FontWeight.w600,
                      color: AppColors.accent)),
            ),
          ],
          const SizedBox(height: 10),
          Text(s.motif, style: interStyle(size: 13, color: AppColors.textDark)),
          const SizedBox(height: 14),

          // Progression des votes (agrégats uniquement → anonyme)
          Row(
            children: [
              _voteChip(Icons.thumb_up_alt_outlined, '${s.votesOui}', AppColors.success),
              const SizedBox(width: 10),
              _voteChip(Icons.thumb_down_alt_outlined, '${s.votesNon}', AppColors.error),
              const Spacer(),
              Text('${s.totalVotants}/${s.totalEligibles} ont voté',
                  style: interStyle(size: 11, color: AppColors.textLight)),
            ],
          ),

          // Actions de vote OU rappel du vote / statut
          if (s.votable) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onVote(s, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approuver'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onVote(s, false),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ] else if (s.monVote != null) ...[
            const SizedBox(height: 10),
            Text(s.monVote == true ? 'Vous avez approuvé' : 'Vous avez refusé',
                style: interStyle(size: 12, weight: FontWeight.w600,
                    color: s.monVote == true ? AppColors.success : AppColors.error)),
          ] else if (s.statut == 'en_cours' && s.expire) ...[
            const SizedBox(height: 10),
            Text('Vote clôturé (délai écoulé)',
                style: interStyle(size: 12, color: AppColors.textLight)),
          ],
        ],
      ),
    );
  }

  Widget _voteChip(IconData icon, String value, Color color) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: interStyle(size: 13, weight: FontWeight.w700, color: color)),
        ],
      );
}

// ─────────────────────────────────────────────────────────
//  SHEET : NOUVELLE DEMANDE
// ─────────────────────────────────────────────────────────
class _NewSuturaSheet extends StatefulWidget {
  final Tontine tontine;
  final VoidCallback onDone;
  const _NewSuturaSheet({required this.tontine, required this.onDone});

  @override
  State<_NewSuturaSheet> createState() => _NewSuturaSheetState();
}

class _NewSuturaSheetState extends State<_NewSuturaSheet> {
  final _api = ApiService();
  final _montCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();
  int _duree = 10; // minutes (5 ou 10)
  bool _loading = false;

  @override
  void dispose() { _montCtrl.dispose(); _motifCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final montant = double.tryParse(_montCtrl.text.trim()) ?? 0;
    final motif = _motifCtrl.text.trim();
    if (montant <= 0) { showError(context, 'Entrez un montant valide'); return; }
    if (motif.length < 10) { showError(context, 'Le motif doit faire au moins 10 caractères'); return; }

    setState(() => _loading = true);
    try {
      await _api.createSutura(widget.tontine.id, montant, motif, _duree);
      if (!mounted) return;
      showSuccess(context, 'Demande soumise anonymement');
      widget.onDone();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response?.data['message'] as String?
          : null;
      if (mounted) showError(context, msg ?? 'Demande impossible');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
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
              Text('Demande d\'urgence',
                  style: soraStyle(size: 20, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Anonyme : le groupe votera sans savoir que c\'est vous.',
                  style: interStyle(size: 13, color: AppColors.textGrey)),
              const SizedBox(height: 20),
              AppField(controller: _montCtrl, label: 'Montant demandé (FCFA)',
                  hint: '50000', keyboardType: TextInputType.number,
                  prefixIcon: Icons.payments_outlined),
              const SizedBox(height: 14),
              AppField(controller: _motifCtrl, label: 'Motif',
                  hint: 'Expliquez brièvement votre besoin (min. 10 caractères)',
                  prefixIcon: Icons.notes_outlined),
              const SizedBox(height: 16),
              Text('Durée du vote',
                  style: interStyle(size: 13, weight: FontWeight.w600,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in [5, 10])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _duree = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(right: d == 5 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _duree == d ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _duree == d ? AppColors.primary : AppColors.border),
                          ),
                          child: Text('$d minutes',
                              textAlign: TextAlign.center,
                              style: interStyle(size: 13, weight: FontWeight.w600,
                                  color: _duree == d ? Colors.white : AppColors.textGrey)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Soumettre la demande',
                  onPressed: _submit, loading: _loading),
            ],
          ),
        ),
      );
}
