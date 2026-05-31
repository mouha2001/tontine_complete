import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Étapes du flux d'authentification unifié.
/// L'utilisateur saisit son numéro, reçoit un OTP : s'il a déjà un compte il
/// est connecté directement ; sinon l'étape [profile] s'affiche pour qu'il
/// renseigne son prénom et son nom et finalise son inscription.
enum _Step { phone, otp, profile }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _telCtrl    = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _nomCtrl    = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  _Step _step = _Step.phone;

  @override
  void dispose() {
    _telCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _inviteCtrl.dispose();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  String get _otp => _otpCtrl.map((c) => c.text).join();

  // ── Étape 1 → 2 : envoyer l'OTP ───────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_telCtrl.text.trim().isEmpty) {
      showError(context, 'Entrez votre numéro de téléphone');
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(_telCtrl.text.trim(), 'membre');
    if (ok && mounted) {
      setState(() => _step = _Step.otp);
    } else if (mounted) {
      showError(context, auth.error ?? 'Erreur envoi OTP');
    }
  }

  // ── Étape 2 : vérifier l'OTP (connexion OU détection nouveau compte) ───────
  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      showError(context, 'Entrez le code à 6 chiffres');
      return;
    }
    final auth = context.read<AuthProvider>();
    final result = await auth.verifyOtp(
      telephone: _telCtrl.text.trim(),
      otp: _otp,
      role: 'membre',
    );
    if (!mounted) return;
    switch (result) {
      case VerifyResult.authenticated:
        break; // _AppShell bascule automatiquement vers l'app
      case VerifyResult.needsRegistration:
        setState(() => _step = _Step.profile); // nouveau compte → profil
      case VerifyResult.error:
        showError(context, auth.error ?? 'Code incorrect');
    }
  }

  // ── Étape 3 : finaliser l'inscription (même OTP + prénom/nom) ──────────────
  Future<void> _register() async {
    if (_prenomCtrl.text.trim().isEmpty) {
      showError(context, 'Entrez votre prénom');
      return;
    }
    if (_nomCtrl.text.trim().isEmpty) {
      showError(context, 'Entrez votre nom');
      return;
    }
    final auth = context.read<AuthProvider>();
    final result = await auth.verifyOtp(
      telephone: _telCtrl.text.trim(),
      otp: _otp,
      role: 'membre',
      prenom: _prenomCtrl.text.trim(),
      nom: _nomCtrl.text.trim(),
      inviteCode: _inviteCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result == VerifyResult.authenticated) return;
    showError(context, auth.error ?? 'Inscription impossible, réessayez');
  }

  void _changeNumber() {
    for (final c in _otpCtrl) c.clear();
    _prenomCtrl.clear();
    _nomCtrl.clear();
    _inviteCtrl.clear();
    setState(() => _step = _Step.phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: switch (_step) {
                  _Step.phone   => _buildPhoneStep(),
                  _Step.otp     => _buildOtpStep(),
                  _Step.profile => _buildProfileStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final (title, subtitle) = switch (_step) {
      _Step.phone => (
          'Connexion',
          'Entrez votre numéro pour recevoir un code',
        ),
      _Step.otp => (
          'Vérification',
          'Code envoyé au ${_telCtrl.text.trim()}',
        ),
      _Step.profile => (
          'Bienvenue 👋',
          'Dernière étape : complétez votre profil',
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 44),
      decoration: const BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _step == _Step.profile
                  ? Icons.person_add_rounded
                  : Icons.savings_rounded,
              color: AppColors.accent,
              size: 30,
            ),
          ),
          const SizedBox(height: 28),
          Text(title,
              style: soraStyle(
                  size: 28, weight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(subtitle, style: interStyle(color: Colors.white60)),
        ],
      ),
    );
  }

  // ── Étape 1 : téléphone ─────────────────────────────────────────────────────
  Widget _buildPhoneStep() {
    return Column(
      children: [
        const SizedBox(height: 8),
        AppField(
          controller: _telCtrl,
          label: 'Numéro de téléphone',
          hint: '77 000 00 00',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 28),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => PrimaryButton(
            label: 'Recevoir le code OTP',
            onPressed: _sendOtp,
            loading: auth.loading,
            icon: Icons.send_rounded,
          ),
        ),
      ],
    );
  }

  // ── Étape 2 : OTP ───────────────────────────────────────────────────────────
  Widget _buildOtpStep() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text('Entrez le code à 6 chiffres',
            style: interStyle(
                size: 14, weight: FontWeight.w500, color: AppColors.textDark)),
        const SizedBox(height: 20),
        _otpBoxes(),
        const SizedBox(height: 28),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => PrimaryButton(
            label: 'Continuer',
            onPressed: _verifyOtp,
            loading: auth.loading,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _changeNumber,
              child: Text('Changer de numéro',
                  style: interStyle(color: AppColors.textGrey)),
            ),
            Text('•', style: interStyle(color: AppColors.textLight)),
            TextButton(
              onPressed: _sendOtp,
              child: Text('Renvoyer le code',
                  style: interStyle(
                      color: AppColors.accent, weight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Étape 3 : profil (nouveau compte uniquement) ────────────────────────────
  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Nous ne connaissons pas encore ce numéro.\n'
            'Renseignez votre prénom et votre nom pour créer votre compte.',
            style: interStyle(size: 14, color: AppColors.textGrey)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: AppField(
                controller: _prenomCtrl,
                label: 'Prénom',
                hint: 'Moussa',
                prefixIcon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppField(
                controller: _nomCtrl,
                label: 'Nom',
                hint: 'Diallo',
                prefixIcon: Icons.person_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppField(
          controller: _inviteCtrl,
          label: 'Code d\'invitation (optionnel)',
          hint: 'Ex: TN-ABCD1234',
          prefixIcon: Icons.vpn_key_outlined,
        ),
        const SizedBox(height: 6),
        Text('Reçu d\'un proche ? Saisissez-le pour rejoindre sa tontine.',
            style: interStyle(size: 12, color: AppColors.textLight)),
        const SizedBox(height: 28),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => PrimaryButton(
            label: 'Créer mon compte',
            onPressed: _register,
            loading: auth.loading,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _changeNumber,
            child: Text('Changer de numéro',
                style: interStyle(color: AppColors.textGrey)),
          ),
        ),
      ],
    );
  }

  // ── 6 cases OTP partagées ───────────────────────────────────────────────────
  Widget _otpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) => Container(
        width: 46,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: TextFormField(
          controller: _otpCtrl[i],
          focusNode: _otpFocus[i],
          textAlign: TextAlign.center,
          style: soraStyle(size: 20, weight: FontWeight.w700),
          keyboardType: TextInputType.number,
          inputFormatters: [
            LengthLimitingTextInputFormatter(1),
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
          ),
          onChanged: (v) {
            if (v.isNotEmpty && i < 5) _otpFocus[i + 1].requestFocus();
            if (v.isEmpty && i > 0) _otpFocus[i - 1].requestFocus();
          },
        ),
      )),
    );
  }
}
