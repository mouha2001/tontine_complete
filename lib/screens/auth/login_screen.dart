import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _telCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _otpSent = false;

  @override
  void dispose() {
    _telCtrl.dispose();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_telCtrl.text.trim().isEmpty) {
      showError(context, 'Entrez votre numéro de téléphone');
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(_telCtrl.text.trim(), 'membre');
    if (ok && mounted) {
      setState(() => _otpSent = true);
    } else if (mounted) {
      showError(context, auth.error ?? 'Erreur envoi OTP');
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
    );
    if (!ok && mounted) {
      showError(context, auth.error ?? 'Code incorrect');
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 44),
                decoration: const BoxDecoration(
                  gradient: AppColors.darkGradient,
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(36)),
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
                      child: const Icon(Icons.savings_rounded,
                          color: AppColors.accent, size: 30),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _otpSent ? 'Vérification' : 'Connexion',
                      style: soraStyle(
                          size: 28,
                          weight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _otpSent
                          ? 'Code envoyé au ${_telCtrl.text.trim()}'
                          : 'Entrez votre numéro pour recevoir un code',
                      style: interStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),

              // ── Contenu ─────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    if (!_otpSent) ...[
                      // ── Étape 1 : Téléphone ─────────
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
                    ] else ...[
                      // ── Étape 2 : OTP ───────────────
                      Text(
                        'Entrez le code à 6 chiffres',
                        style: interStyle(
                            size: 14,
                            weight: FontWeight.w500,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(height: 20),

                      // 6 cases OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) => Container(
                          width: 46,
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextFormField(
                            controller: _otpCtrl[i],
                            focusNode: _otpFocus[i],
                            textAlign: TextAlign.center,
                            style: soraStyle(
                                size: 20, weight: FontWeight.w700),
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
                              if (v.isNotEmpty && i < 5) {
                                _otpFocus[i + 1].requestFocus();
                              }
                              if (v.isEmpty && i > 0) {
                                _otpFocus[i - 1].requestFocus();
                              }
                            },
                          ),
                        )),
                      ),
                      const SizedBox(height: 28),

                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => PrimaryButton(
                          label: 'Se connecter',
                          onPressed: _verifyOtp,
                          loading: auth.loading,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Renvoyer / changer numéro
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _resetOtp,
                            child: Text('Changer de numéro',
                                style: interStyle(
                                    color: AppColors.textGrey)),
                          ),
                          Text('•',
                              style: interStyle(color: AppColors.textLight)),
                          TextButton(
                            onPressed: _sendOtp,
                            child: Text('Renvoyer le code',
                                style: interStyle(
                                    color: AppColors.accent,
                                    weight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 16),

                    // ── Lien vers Register ──────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Pas encore de compte ? ",
                            style: interStyle(size: 14)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: Text(
                            "S'inscrire",
                            style: interStyle(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}