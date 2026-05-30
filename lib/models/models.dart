import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── USER ──────────────────────────────────────────────────
class User {
  final int id;
  final String nom;
  final String prenom;
  final String telephone;
  final String? email;
  final String role;

  User({required this.id, required this.nom, required this.prenom,
        required this.telephone, this.email, required this.role});

  String get fullName => '$prenom $nom';
  String get initials => prenom.isNotEmpty ? prenom[0].toUpperCase() : 'U';

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] ?? 0,
    nom: j['nom'] ?? '',
    prenom: j['prenom'] ?? '',
    telephone: j['telephone'] ?? '',
    email: j['email'],
    role: j['role'] ?? 'membre',
  );
}

// ── TONTINE ───────────────────────────────────────────────
class Tontine {
  final int id;
  final String nom;
  final String? description;
  final double montantCotisation;
  final String frequence;
  final int nombreMembres;
  final int membresActifs;
  final String statut;
  final String? code;
  final double totalCagnotte;
  final bool estAdmin;
  final DateTime? dateDebut;

  Tontine({
    required this.id, required this.nom, this.description,
    required this.montantCotisation, required this.frequence,
    required this.nombreMembres, required this.membresActifs,
    required this.statut, this.code, required this.totalCagnotte,
    this.estAdmin = false, this.dateDebut,
  });

  factory Tontine.fromJson(Map<String, dynamic> j) => Tontine(
    id: j['id'] ?? 0,
    nom: j['nom'] ?? '',
    description: j['description'],
    montantCotisation: double.tryParse('${j['montant_cotisation'] ?? 0}') ?? 0,
    frequence: j['frequence'] ?? 'mensuel',
    nombreMembres: j['nombre_membres'] ?? 0,
    membresActifs: j['membres_actifs'] ?? 0,
    statut: j['statut'] ?? 'active',
    code: j['code'],
    totalCagnotte: double.tryParse('${j['total_cagnotte'] ?? 0}') ?? 0,
    estAdmin: j['est_admin'] == true,
    dateDebut: j['date_debut'] != null ? DateTime.tryParse(j['date_debut']) : null,
  );

  Color get statutColor {
    switch (statut) {
      case 'active': return AppColors.success;
      case 'terminee': return AppColors.textGrey;
      default: return AppColors.warning;
    }
  }

  String get statutLabel {
    switch (statut) {
      case 'active': return 'Active';
      case 'terminee': return 'Terminée';
      default: return 'En attente';
    }
  }

  String get frequenceLabel {
    switch (frequence) {
      case 'hebdomadaire': return 'Hebdomadaire';
      case 'bimensuel': return 'Bimensuel';
      default: return 'Mensuel';
    }
  }
}

// ── COTISATION ────────────────────────────────────────────
class Cotisation {
  final int id;
  final int tontineId;
  final int userId;
  final String? userName;
  final double montant;
  final String statut;
  final DateTime? datePaiement;
  final String? periode;

  Cotisation({required this.id, required this.tontineId, required this.userId,
              this.userName, required this.montant, required this.statut,
              this.datePaiement, this.periode});

  factory Cotisation.fromJson(Map<String, dynamic> j) => Cotisation(
    id: j['id'] ?? 0,
    tontineId: j['tontine_id'] ?? 0,
    userId: j['user_id'] ?? 0,
    userName: j['user'] != null ? '${j['user']['prenom']} ${j['user']['nom']}' : null,
    montant: double.tryParse('${j['montant'] ?? 0}') ?? 0,
    statut: j['statut'] ?? 'en_attente',
    datePaiement: j['date_paiement'] != null ? DateTime.tryParse(j['date_paiement']) : null,
    periode: j['periode_concernee'],
  );

  Color get color {
    switch (statut) {
      case 'payee': return AppColors.success;
      case 'retard': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  IconData get icon {
    switch (statut) {
      case 'payee': return Icons.check_circle_rounded;
      case 'retard': return Icons.error_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String get statutLabel {
    switch (statut) {
      case 'payee': return 'Payée';
      case 'retard': return 'En retard';
      default: return 'En attente';
    }
  }
}

// ── SUTURA (Tirage) ───────────────────────────────────────
class Sutura {
  final int id;
  final int tour;
  final String? beneficiaire;
  final double montantRecu;
  final DateTime? date;
  final String statut;

  Sutura({required this.id, required this.tour, this.beneficiaire,
          required this.montantRecu, this.date, required this.statut});

  factory Sutura.fromJson(Map<String, dynamic> j) => Sutura(
    id: j['id'] ?? 0,
    tour: j['tour'] ?? 0,
    beneficiaire: j['beneficiaire'] != null
        ? '${j['beneficiaire']['prenom']} ${j['beneficiaire']['nom']}'
        : j['beneficiaire_nom'],
    montantRecu: double.tryParse('${j['montant_recu'] ?? 0}') ?? 0,
    date: j['date'] != null ? DateTime.tryParse(j['date']) : null,
    statut: j['statut'] ?? 'effectue',
  );
}

// ── NOTIFICATION ──────────────────────────────────────────
class AppNotification {
  final int id;
  final String titre;
  final String message;
  final String type;
  final bool lue;
  final DateTime? createdAt;

  AppNotification({required this.id, required this.titre, required this.message,
                   required this.type, required this.lue, this.createdAt});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] ?? 0,
    titre: j['titre'] ?? '',
    message: j['message'] ?? '',
    type: j['type'] ?? 'info',
    lue: j['lue'] == true || j['lue'] == 1,
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
  );

  Color get color {
    switch (type) {
      case 'cotisation': return AppColors.success;
      case 'sutura':     return AppColors.gold;
      case 'retard':     return AppColors.error;
      default:           return AppColors.primary;
    }
  }

  IconData get icon {
    switch (type) {
      case 'cotisation': return Icons.payment_rounded;
      case 'sutura':     return Icons.emoji_events_rounded;
      case 'retard':     return Icons.warning_rounded;
      default:           return Icons.info_rounded;
    }
  }
}

// ── DASHBOARD ─────────────────────────────────────────────
class DashboardData {
  final int totalTontines;
  final double totalCotisations;
  final int prochainTour;
  final double montantAttendu;
  final int urgencesEnCours;
  final List<Map<String, dynamic>> activiteRecente;

  DashboardData({
    required this.totalTontines,
    required this.totalCotisations,
    required this.prochainTour,
    required this.montantAttendu,
    required this.urgencesEnCours,
    required this.activiteRecente,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
    totalTontines: j['total_tontines'] ?? 0,
    totalCotisations:
        double.tryParse('${j['total_cotisations'] ?? 0}') ?? 0,
    prochainTour: j['prochain_tour'] ?? 0,
    montantAttendu:
        double.tryParse('${j['montant_attendu'] ?? 0}') ?? 0,
    urgencesEnCours: j['urgences_en_cours'] ?? 0,
    activiteRecente:
        List<Map<String, dynamic>>.from(j['activite_recente'] ?? []),
  );
}