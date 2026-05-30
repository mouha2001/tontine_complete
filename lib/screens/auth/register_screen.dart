import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _prenomCtrl = TextEditingController();
  final _nomCtrl    = TextEditingController();
  final _telCtrl    = TextEditingController();

  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus =
      List.generate(6, (_) => FocusNode());

  bool _otpSent = false;

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _telCtrl.dispose();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_prenomCtrl.text.trim().isEmpty) {
      showError(context, 'Entrez votre prénom');
      return;
    }
    if (_nomCtrl.text.trim().isEmpty) {
      showError(context, 'Entrez votre nom');
      return;
    }
    if (_telCtrl.text.trim().isEmpty) {
      showError(context, 'Entrez votre numéro de téléphone');
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(_telCtrl.text.trim(), 'membre');
    if (ok && mounted) {
      setState(() => _otpSent = true);
    } else if (mounted) {
      showError(context, auth.error ?? 'Erreur lors de l\'envoi du code');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.map((c) => c.text).join();
    if (otp.length != 6) {
      showError(context, 'Entrez le code à 6 chiffres');
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(
      telephone: _telCtrl.text.trim(),
      otp: otp,
      role: 'membre',
      prenom: _prenomCtrl.text.trim(),
      nom: _nomCtrl.text.trim(),
    );
    if (!ok && mounted) {
      showError(context, auth.error ?? 'Code incorrect ou expiré');
    }
  }

  void _resetOtp() {
    for (final c in _otpCtrl) c.clear();
    setState(() => _otpSent = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_otpSent ? 'Vérification' : 'Créer un compte'),
        backgroundColor: AppColors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _otpSent ? _buildOtpStep() : _buildFormStep(),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.darkGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inscription',
                        style: soraStyle(size: 18,
                            weight: FontWeight.w700, color: Colors.white)),
                    Text('Créez votre compte gratuitement',
                        style: interStyle(size: 12, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Prénom + Nom
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

        // Téléphone
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
        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Déjà un compte ? ', style: interStyle(size: 14)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('Se connecter',
                  style: interStyle(size: 14,
                      weight: FontWeight.w700, color: AppColors.accent)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sms_rounded,
              color: AppColors.accent, size: 36),
        ),
        const SizedBox(height: 20),
        Text('Code envoyé !',
            style: soraStyle(size: 22, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Bonjour ${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()} 👋',
          style: soraStyle(size: 15, weight: FontWeight.w600,
              color: AppColors.accent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Entrez le code reçu au\n${_telCtrl.text.trim()}',
          style: interStyle(size: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        // 6 cases OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => Container(
            width: 46, height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: TextFormField(
              controller: _otpCtrl[i],
              focusNode: _otpFocus[i],
              textAlign: TextAlign.center,
              style: soraStyle(size: 22, weight: FontWeight.w700),
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
                  borderSide: const BorderSide(
                      color: AppColors.accent, width: 2),
                ),
              ),
              onChanged: (v) {
                if (v.isNotEmpty && i < 5) _otpFocus[i + 1].requestFocus();
                if (v.isEmpty && i > 0)    _otpFocus[i - 1].requestFocus();
              },
            ),
          )),
        ),
        const SizedBox(height: 32),

        Consumer<AuthProvider>(
          builder: (_, auth, __) => PrimaryButton(
            label: 'Créer mon compte',
            onPressed: _verifyOtp,
            loading: auth.loading,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _resetOtp,
              child: Text('Modifier mes infos',
                  style: interStyle(color: AppColors.textGrey)),
            ),
            Text(' • ', style: interStyle(color: AppColors.textLight)),
            TextButton(
              onPressed: _sendOtp,
              child: Text('Renvoyer le code',
                  style: interStyle(color: AppColors.accent,
                      weight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}