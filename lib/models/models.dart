import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Libellé « Mois Année » en français (sans dépendance de locale intl)
const _moisFr = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
String moisAnnee(DateTime d) => '${_moisFr[d.month]} ${d.year}';

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
  final int partsTotal;       // capacité en parts/tours (= nombre_membres)
  final int partsActuelles;   // somme des parts déjà prises
  final int placesRestantes;  // parts encore disponibles
  final int mesParts;         // parts de l'utilisateur courant
  final String statut;
  final String? code;
  final String? inviteUrl;
  final double totalCagnotte;
  final bool estAdmin;
  final DateTime? dateDebut;

  Tontine({
    required this.id, required this.nom, this.description,
    required this.montantCotisation, required this.frequence,
    required this.nombreMembres, required this.membresActifs,
    this.partsTotal = 0, this.partsActuelles = 0,
    this.placesRestantes = 0, this.mesParts = 0,
    required this.statut, this.code, this.inviteUrl, required this.totalCagnotte,
    this.estAdmin = false, this.dateDebut,
  });

  factory Tontine.fromJson(Map<String, dynamic> j) => Tontine(
    id: j['id'] ?? 0,
    nom: j['nom'] ?? '',
    description: j['description'],
    montantCotisation: double.tryParse('${j['montant_cotisation'] ?? 0}') ?? 0,
    frequence: j['frequence'] ?? 'mensuel',
    nombreMembres: j['nombre_membres'] ?? 0,
    membresActifs: j['membres_actuels'] ?? 0,
    partsTotal: j['nombre_parts_total'] ?? j['nombre_membres'] ?? 0,
    partsActuelles: j['parts_actuelles'] ?? 0,
    placesRestantes: j['places_restantes'] ?? 0,
    mesParts: j['mes_parts'] ?? 0,
    statut: j['statut'] ?? 'active',
    code: j['invite_code'],
    inviteUrl: j['invite_url'],
    totalCagnotte: double.tryParse('${j['total_collecte'] ?? 0}') ?? 0,
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
      case '2min': return '2 min (test)';
      case 'quotidien': return 'Quotidien';
      case 'hebdomadaire': return 'Hebdomadaire';
      case 'bimensuel': return 'Bimensuel';
      case 'bimestriel': return 'Bimestriel';
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
  final DateTime? periode;

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
    datePaiement: (j['paye_le'] ?? j['date_paiement']) != null
        ? DateTime.tryParse(j['paye_le'] ?? j['date_paiement'])?.toLocal()
        : null,
    periode: j['periode'] != null ? DateTime.tryParse(j['periode']) : null,
  );

  String? get periodeLabel => periode == null ? null : moisAnnee(periode!);

  Color get color {
    switch (statut) {
      case 'confirme': return AppColors.success;
      case 'echoue': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  IconData get icon {
    switch (statut) {
      case 'confirme': return Icons.check_circle_rounded;
      case 'echoue': return Icons.cancel_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String get statutLabel {
    switch (statut) {
      case 'confirme': return 'Confirmée';
      case 'echoue': return 'Rejetée';
      default: return 'En attente';
    }
  }
}

// ── TIRAGE (historique des tours) ─────────────────────────
class Tirage {
  final int id;
  final int tour;
  final String? gagnant;
  final double montant;
  final DateTime? date;

  Tirage({required this.id, required this.tour, this.gagnant,
          required this.montant, this.date});

  factory Tirage.fromJson(Map<String, dynamic> j) => Tirage(
    id: j['id'] ?? 0,
    tour: j['tour'] ?? 0,
    gagnant: j['gagnant'] != null
        ? '${j['gagnant']['prenom'] ?? ''} ${j['gagnant']['nom'] ?? ''}'.trim()
        : null,
    montant: double.tryParse('${j['montant_attribue'] ?? 0}') ?? 0,
    date: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
  );
}

// ── SUTURA (demande d'urgence) ────────────────────────────
class Sutura {
  final int id;
  final int tontineId;
  final double montantDemande;
  final String motif;
  final String statut;         // en_cours / approuve / rejete
  final int votesOui;
  final int votesNon;
  final int totalVotants;
  final int totalEligibles;
  final bool? monVote;         // null = pas encore voté
  final bool estMien;          // visible uniquement par le demandeur (anonymat)
  final bool peutVoter;
  final bool honoree;          // urgence approuvée déjà honorée par un tirage
  final DateTime? voteExpiresAt;
  final DateTime? createdAt;

  Sutura({
    required this.id, required this.tontineId, required this.montantDemande,
    required this.motif, required this.statut, this.votesOui = 0,
    this.votesNon = 0, this.totalVotants = 0, this.totalEligibles = 0,
    this.monVote, this.estMien = false, this.peutVoter = false,
    this.honoree = false, this.voteExpiresAt, this.createdAt,
  });

  factory Sutura.fromJson(Map<String, dynamic> j) => Sutura(
    id: j['id'] ?? 0,
    tontineId: j['tontine_id'] ?? 0,
    montantDemande: double.tryParse('${j['montant_demande'] ?? 0}') ?? 0,
    motif: j['motif'] ?? '',
    statut: j['statut'] ?? 'en_cours',
    votesOui: j['votes_oui'] ?? 0,
    votesNon: j['votes_non'] ?? 0,
    totalVotants: j['total_votants'] ?? 0,
    totalEligibles: j['total_eligibles'] ?? 0,
    monVote: j['mon_vote'],
    estMien: j['est_mien'] == true,
    peutVoter: j['peut_voter'] == true,
    honoree: j['honoree'] == true,
    voteExpiresAt: j['vote_expires_at'] != null
        ? DateTime.tryParse(j['vote_expires_at'])?.toLocal()
        : null,
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
  );

  // Temps restant avant la fin du vote (peut être négatif si expiré)
  Duration get tempsRestant => voteExpiresAt == null
      ? Duration.zero
      : voteExpiresAt!.difference(DateTime.now());

  bool get expire => voteExpiresAt != null && tempsRestant.isNegative;

  // Vote possible côté UI : autorisé par le serveur ET délai non écoulé
  bool get votable => peutVoter && !expire;

  String get statutLabel {
    if (honoree) return 'Honorée';
    switch (statut) {
      case 'approuve': return 'Approuvée';
      case 'rejete': return 'Rejetée';
      default: return 'En cours';
    }
  }

  Color get statutColor {
    switch (statut) {
      case 'approuve': return AppColors.success;
      case 'rejete': return AppColors.error;
      default: return AppColors.warning;
    }
  }
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
    // l'API renvoie `lu` (et non `lue`) — fallback de sécurité
    lue: j['lu'] == true || j['lu'] == 1 || j['lue'] == true,
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
// ── RAPPEL DE COTISATION ──────────────────────────────────
class RappelCotisation {
  final int tontineId;
  final String tontineNom;
  final int parts;
  final double montant;

  RappelCotisation({required this.tontineId, required this.tontineNom,
      required this.parts, required this.montant});

  factory RappelCotisation.fromJson(Map<String, dynamic> j) => RappelCotisation(
    tontineId: j['tontine_id'] ?? 0,
    tontineNom: j['tontine_nom'] ?? '',
    parts: j['parts'] ?? 1,
    montant: double.tryParse('${j['montant'] ?? 0}') ?? 0,
  );
}

class DashboardData {
  final int totalTontines;
  final int tontinesActives;
  final int totalMembres;
  final double totalCollecte;
  final int urgencesEnCours;
  final double totalCotise;
  final double montantDuMois;
  final List<RappelCotisation> rappels;
  final List<Map<String, dynamic>> activitesRecentes;

  DashboardData({
    required this.totalTontines,
    required this.tontinesActives,
    required this.totalMembres,
    required this.totalCollecte,
    required this.urgencesEnCours,
    this.totalCotise = 0,
    this.montantDuMois = 0,
    this.rappels = const [],
    required this.activitesRecentes,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
    totalTontines: j['total_tontines'] ?? 0,
    tontinesActives: j['tontines_actives'] ?? 0,
    totalMembres: j['total_membres'] ?? 0,
    totalCollecte: double.tryParse('${j['total_collecte'] ?? 0}') ?? 0,
    urgencesEnCours: j['urgences_en_cours'] ?? 0,
    totalCotise: double.tryParse('${j['total_cotise'] ?? 0}') ?? 0,
    montantDuMois: double.tryParse('${j['montant_du_mois'] ?? 0}') ?? 0,
    rappels: (j['rappels_cotisation'] as List? ?? [])
        .map((r) => RappelCotisation.fromJson(r)).toList(),
    activitesRecentes:
        List<Map<String, dynamic>>.from(j['activites_recentes'] ?? []),
  );
}