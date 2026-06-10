import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../cotisations/cotisations_screen.dart';
import '../sutura/sutura_screen.dart';

// ─────────────────────────────────────────────────────────
//  LISTE DES TONTINES
// ─────────────────────────────────────────────────────────
class TontinesScreen extends StatefulWidget {
  const TontinesScreen({super.key});

  @override
  State<TontinesScreen> createState() => _TontinesScreenState();
}

class _TontinesScreenState extends State<TontinesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<Tontine> _tontines = [];
  bool _loading = true;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTontines();
      final list = (res['data'] as List? ?? [])
          .map((j) => Tontine.fromJson(j)).toList();
      setState(() => _tontines = list);
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Tontine> get _active    => _tontines.where((t) => t.statut == 'active').toList();
  List<Tontine> get _autres    => _tontines.where((t) => t.statut != 'active').toList();

  void _openCreate() => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSheet(onDone: () { Navigator.pop(context); _load(); }));

  void _openJoin() => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JoinSheet(onDone: () { Navigator.pop(context); _load(); }));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Mes Tontines'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.group_add_rounded),
              tooltip: 'Rejoindre',
              onPressed: _openJoin),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.accent,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'Actives (${_active.length})'),
            Tab(text: 'Autres (${_autres.length})'),
          ],
        ),
      ),
      body: _loading
          ? const FullScreenLoader()
          : TabBarView(
              controller: _tab,
              children: [
                _Liste(tontines: _active, onRefresh: _load,
                    empty: 'Aucune tontine active'),
                _Liste(tontines: _autres, onRefresh: _load,
                    empty: 'Aucune tontine terminée'),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  LISTE
// ─────────────────────────────────────────────────────────
class _Liste extends StatelessWidget {
  final List<Tontine> tontines;
  final Future<void> Function() onRefresh;
  final String empty;

  const _Liste({required this.tontines, required this.onRefresh, required this.empty});

  @override
  Widget build(BuildContext context) {
    if (tontines.isEmpty) {
      return EmptyState(icon: Icons.savings_outlined, message: empty,
          subMessage: 'Créez ou rejoignez une tontine pour commencer');
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tontines.length,
        itemBuilder: (_, i) => _TontineCard(tontine: tontines[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  CARTE TONTINE
// ─────────────────────────────────────────────────────────
class _TontineCard extends StatelessWidget {
  final Tontine tontine;
  const _TontineCard({required this.tontine});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return GestureDetector(
      onTap: () => Navigator.push(context,
          appRoute(TontineDetailScreen(tontine: tontine))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom + statut
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.darkGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.savings_rounded,
                      color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tontine.nom,
                          style: soraStyle(size: 15, weight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      Text(tontine.frequenceLabel,
                          style: interStyle(size: 12)),
                    ],
                  ),
                ),
                StatusBadge(label: tontine.statutLabel, color: tontine.statutColor),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),

            // Infos
            Row(
              children: [
                _Chip(Icons.payments_outlined,
                    '${fmt.format(tontine.montantCotisation)} FCFA',
                    AppColors.success),
                const SizedBox(width: 10),
                _Chip(Icons.confirmation_number_outlined,
                    '${tontine.partsActuelles}/${tontine.partsTotal} parts',
                    AppColors.primary),
                const Spacer(),
                if (tontine.estAdmin)
                  StatusBadge(label: '★ Admin', color: AppColors.gold),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: interStyle(size: 12, weight: FontWeight.w600, color: color)),
    ],
  );
}

// ─────────────────────────────────────────────────────────
//  DÉTAIL TONTINE
// ─────────────────────────────────────────────────────────
class TontineDetailScreen extends StatefulWidget {
  final Tontine tontine;
  const TontineDetailScreen({super.key, required this.tontine});

  @override
  State<TontineDetailScreen> createState() => _TontineDetailScreenState();
}

class _TontineDetailScreenState extends State<TontineDetailScreen> {
  final _api = ApiService();
  List<Tirage> _tirages = [];
  bool _loading = true;
  bool _tirageEnCours = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTirages(widget.tontine.id);
      setState(() => _tirages = (res['data'] as List? ?? [])
          .map((j) => Tirage.fromJson(j)).toList());
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _lancerTirage() async {
    setState(() => _tirageEnCours = true);
    try {
      final res = await _api.lancerTirage(widget.tontine.id);
      if (mounted) {
        final g = res['gagnant'];
        final nom = g != null ? '${g['prenom'] ?? ''} ${g['nom'] ?? ''}'.trim() : '';
        showSuccess(context, '🎰 Tour ${res['tour']} : $nom a gagné !');
      }
      await _load();
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response?.data['message'] as String? : null;
      if (mounted) showError(context, msg ?? 'Tirage impossible');
    } finally {
      if (mounted) setState(() => _tirageEnCours = false);
    }
  }

  // Ouvre la feuille de partage native avec le code + lien d'invitation
  void _shareInvite(Tontine t) {
    final msg = StringBuffer()
      ..writeln('Rejoignez ma tontine « ${t.nom} » sur Tontine 🪙')
      ..writeln('Code d\'invitation : ${t.code}');
    if (t.inviteUrl != null) msg.writeln(t.inviteUrl);
    Share.share(msg.toString().trim(),
        subject: 'Invitation à rejoindre une tontine');
  }

  @override
  Widget build(BuildContext context) {
    final t   = widget.tontine;
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.darkGradient),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(t.nom,
                        style: soraStyle(size: 26, weight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(children: [
                      StatusBadge(label: t.statutLabel, color: t.statutColor),
                      const SizedBox(width: 8),
                      Text('• ${t.frequenceLabel}',
                          style: interStyle(size: 13, color: Colors.white60)),
                    ]),
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
                  // Cagnotte
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cagnotte totale',
                            style: interStyle(size: 13, color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text('${fmt.format(t.totalCagnotte)} FCFA',
                            style: soraStyle(size: 28, weight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grille d'infos
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.4,
                    children: [
                      _InfoCell('Cotisation', '${fmt.format(t.montantCotisation)} FCFA'),
                      _InfoCell('Parts', '${t.partsActuelles}/${t.partsTotal}'),
                      _InfoCell('Fréquence', t.frequenceLabel),
                      _InfoCell('Membres', '${t.membresActifs}'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Code invitation
                  if (t.code != null) ...[
                    Text('Code d\'invitation',
                        style: soraStyle(size: 16, weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: t.code!));
                        showSuccess(context, 'Code copié !');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Text(t.code!,
                                style: soraStyle(size: 22, weight: FontWeight.w700,
                                    color: AppColors.primary),),
                            const Spacer(),
                            const Icon(Icons.copy_rounded,
                                size: 20, color: AppColors.textLight),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _shareInvite(t),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Inviter des membres'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Demandes d'urgence (Sutura)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context,
                          appRoute(SuturaScreen(tontine: t))),
                      icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                      label: const Text('Demandes d\'urgence (Sutura)'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tirage du mois (admin uniquement, tontine active)
                  Text('Tirage mensuel',
                      style: soraStyle(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (t.estAdmin && t.statut == 'active')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _tirageEnCours ? null : _lancerTirage,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white),
                        icon: _tirageEnCours
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.casino_rounded, size: 18),
                        label: const Text('Lancer le tirage du mois'),
                      ),
                    )
                  else if (t.statut != 'active')
                    Text('Le tirage sera disponible une fois la tontine active.',
                        style: interStyle(size: 13, color: AppColors.textLight)),
                  const SizedBox(height: 16),

                  Text('Historique des tours',
                      style: soraStyle(size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_loading)
                    const FullScreenLoader()
                  else if (_tirages.isEmpty)
                    const EmptyState(icon: Icons.swap_horiz_rounded,
                        message: 'Aucun tour effectué')
                  else
                    ..._tirages.map((tg) => _TirageItem(tirage: tg, fmt: fmt)),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      appRoute(CotisationsScreen(tontine: widget.tontine))),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('Cotisations'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      appRoute(CotisationsScreen(
                          tontine: widget.tontine, openPay: true))),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('Cotiser'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  const _InfoCell(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: interStyle(size: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: interStyle(size: 13, weight: FontWeight.w600, color: AppColors.textDark),
            overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _TirageItem extends StatelessWidget {
  final Tirage tirage;
  final NumberFormat fmt;
  const _TirageItem({required this.tirage, required this.fmt});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.accent.withOpacity(0.15),
          child: Text('${tirage.tour}',
              style: soraStyle(size: 13, weight: FontWeight.w700,
                  color: AppColors.accent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tirage.gagnant?.isNotEmpty == true
                      ? tirage.gagnant!
                      : 'Gagnant',
                  style: interStyle(size: 13, weight: FontWeight.w600,
                      color: AppColors.textDark)),
              if (tirage.date != null)
                Text(DateFormat('dd/MM/yyyy').format(tirage.date!),
                    style: interStyle(size: 11)),
            ],
          ),
        ),
        Text('${fmt.format(tirage.montant)} FCFA',
            style: interStyle(size: 13, weight: FontWeight.w700,
                color: AppColors.success)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  SHEET : CRÉER UNE TONTINE
// ─────────────────────────────────────────────────────────
class _CreateSheet extends StatefulWidget {
  final VoidCallback onDone;
  const _CreateSheet({required this.onDone});

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _api        = ApiService();
  final _nomCtrl    = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _montCtrl   = TextEditingController();
  final _memCtrl    = TextEditingController();
  String _freq      = 'mensuel';
  int _parts        = 1;
  bool _loading     = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.createTontine({
        'nom': _nomCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'montant_cotisation': _montCtrl.text.trim(),
        'nombre_membres': _memCtrl.text.trim(),
        'frequence': _freq,
        'nombre_parts': _parts,
      });
      widget.onDone();
    } catch (_) {
      if (mounted) showError(context, 'Erreur lors de la création');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _BottomSheet(
    title: 'Créer une tontine',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          AppField(controller: _nomCtrl, label: 'Nom de la tontine',
              hint: 'Ex: Tontine Famille Diallo',
              validator: (v) => v!.isEmpty ? 'Requis' : null),
          const SizedBox(height: 14),
          AppField(controller: _descCtrl, label: 'Description (optionnel)',
              hint: 'Courte description'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: AppField(controller: _montCtrl, label: 'Montant (FCFA)',
                  hint: '10000', keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Requis' : null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppField(controller: _memCtrl, label: 'Parts (tours)',
                  hint: '10', keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Requis' : null),
            ),
          ]),
          const SizedBox(height: 14),
          // Sélecteur fréquence
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Fréquence', style: interStyle(size: 13, weight: FontWeight.w600,
                color: AppColors.textDark)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final f in const [
                ['quotidien', 'Quotidien'],
                ['hebdomadaire', 'Hebdo'],
                ['bimensuel', '2×/mois'],
                ['mensuel', 'Mensuel'],
                ['bimestriel', 'Tous les 2 mois'],
              ])
                GestureDetector(
                  onTap: () => setState(() => _freq = f[0]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _freq == f[0] ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _freq == f[0] ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(f[1],
                        style: interStyle(size: 12, weight: FontWeight.w600,
                            color: _freq == f[0] ? Colors.white : AppColors.textGrey)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Mes parts', style: interStyle(size: 13,
                weight: FontWeight.w600, color: AppColors.textDark)),
          ),
          const SizedBox(height: 8),
          _PartsSelector(value: _parts, onChanged: (p) => setState(() => _parts = p)),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Créer la tontine', onPressed: _submit, loading: _loading),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  SHEET : REJOINDRE UNE TONTINE
// ─────────────────────────────────────────────────────────
class _JoinSheet extends StatefulWidget {
  final VoidCallback onDone;
  const _JoinSheet({required this.onDone});

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _api     = ApiService();
  final _codeCtrl = TextEditingController();
  int _parts     = 1;
  bool _loading  = false;

  Future<void> _join() async {
    if (_codeCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _api.joinTontine(_codeCtrl.text.trim(), parts: _parts);
      widget.onDone();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response?.data['message'] as String?
          : null;
      if (mounted) {
        showError(context, msg ?? 'Code invalide ou tontine introuvable');
      }
    } catch (_) {
      if (mounted) showError(context, 'Code invalide ou tontine introuvable');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _BottomSheet(
    title: 'Rejoindre une tontine',
    subtitle: 'Entrez le code donné par l\'administrateur',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppField(controller: _codeCtrl, label: 'Code d\'invitation',
            hint: 'Ex: TN-ABCD1234', prefixIcon: Icons.vpn_key_outlined),
        const SizedBox(height: 16),
        Text('Nombre de parts', style: interStyle(size: 13,
            weight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        _PartsSelector(value: _parts, onChanged: (p) => setState(() => _parts = p)),
        const SizedBox(height: 6),
        Text('2 ou 3 parts = vous cotisez plus et recevez la cagnotte autant de fois.',
            style: interStyle(size: 12, color: AppColors.textLight)),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Rejoindre', onPressed: _join, loading: _loading),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  SÉLECTEUR DE PARTS (1 / 2 / 3)
// ─────────────────────────────────────────────────────────
class _PartsSelector extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  const _PartsSelector({required this.value, required this.onChanged, this.max = 3});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int p = 1; p <= max; p++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: p != max ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: value == p ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: value == p ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  p == 1 ? '1 part' : '$p parts',
                  textAlign: TextAlign.center,
                  style: interStyle(size: 12, weight: FontWeight.w600,
                      color: value == p ? Colors.white : AppColors.textGrey),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  BOTTOM SHEET CONTAINER RÉUTILISABLE
// ─────────────────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _BottomSheet({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text(title, style: soraStyle(size: 20, weight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: interStyle(size: 13)),
          ],
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}