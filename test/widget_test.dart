import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tontine/models/models.dart';
import 'package:tontine/providers/auth_provider.dart';
import 'package:tontine/screens/auth/login_screen.dart';

void main() {
  group('Modèles — mappings API', () {
    test('Tontine.fromJson lit invite_code / membres_actuels / total_collecte / est_admin', () {
      final t = Tontine.fromJson({
        'id': 1,
        'nom': 'Tontine QA',
        'invite_code': 'TN-ABCD1234',
        'invite_url': 'https://tontine.sn/invite/TN-ABCD1234',
        'membres_actuels': 2,
        'nombre_membres': 5,
        'total_collecte': 15000,
        'est_admin': true,
        'montant_cotisation': 5000,
        'frequence': 'mensuel',
        'statut': 'active',
      });
      expect(t.code, 'TN-ABCD1234');
      expect(t.inviteUrl, 'https://tontine.sn/invite/TN-ABCD1234');
      expect(t.membresActifs, 2);
      expect(t.nombreMembres, 5);
      expect(t.totalCagnotte, 15000);
      expect(t.estAdmin, isTrue);
    });

    test('Tontine.fromJson lit les parts (capacité, mes_parts) et le label de fréquence', () {
      final t = Tontine.fromJson({
        'id': 1,
        'nom': 'T Parts',
        'frequence': 'bimestriel',
        'montant_cotisation': 10000,
        'nombre_membres': 5,
        'nombre_parts_total': 5,
        'parts_actuelles': 4,
        'places_restantes': 1,
        'mes_parts': 2,
        'statut': 'active',
      });
      expect(t.partsTotal, 5);
      expect(t.partsActuelles, 4);
      expect(t.placesRestantes, 1);
      expect(t.mesParts, 2);
      expect(t.frequenceLabel, 'Bimestriel');
    });

    test('User.fromJson lit prenom et calcule fullName / initials', () {
      final u = User.fromJson({
        'id': 1,
        'nom': 'Sow',
        'prenom': 'Awa',
        'telephone': '771234567',
        'role': 'membre',
      });
      expect(u.prenom, 'Awa');
      expect(u.fullName, 'Awa Sow');
      expect(u.initials, 'A');
    });

    test('DashboardData.fromJson lit la shape unifiée du backend', () {
      final d = DashboardData.fromJson({
        'total_tontines': 3,
        'tontines_actives': 1,
        'total_membres': 12,
        'total_collecte': 250000,
        'urgences_en_cours': 2,
        'activites_recentes': [
          {'type': 'cotisation', 'label': 'Awa Sow a cotisé 5000 FCFA', 'tontine': 'T'},
        ],
      });
      expect(d.totalTontines, 3);
      expect(d.totalMembres, 12);
      expect(d.totalCollecte, 250000);
      expect(d.urgencesEnCours, 2);
      expect(d.activitesRecentes, hasLength(1));
    });

    test('Tirage.fromJson lit tour / gagnant / montant', () {
      final t = Tirage.fromJson({
        'id': 1, 'tour': 3, 'montant_attribue': 50000,
        'gagnant': {'prenom': 'Awa', 'nom': 'Sow'},
        'created_at': '2026-05-30T10:00:00.000000Z',
      });
      expect(t.tour, 3);
      expect(t.gagnant, 'Awa Sow');
      expect(t.montant, 50000);
    });

    test('Sutura.fromJson lit la demande d\'urgence (agrégats anonymes)', () {
      final s = Sutura.fromJson({
        'id': 1, 'tontine_id': 2, 'montant_demande': 50000,
        'motif': 'Frais médicaux', 'statut': 'en_cours',
        'votes_oui': 2, 'votes_non': 1, 'total_votants': 3,
        'total_eligibles': 4, 'mon_vote': true, 'est_mien': false,
        'peut_voter': false,
      });
      expect(s.montantDemande, 50000);
      expect(s.votesOui, 2);
      expect(s.totalEligibles, 4);
      expect(s.monVote, isTrue);
      expect(s.estMien, isFalse);
      expect(s.statutLabel, 'En cours');
    });

    test('AppNotification lit `lu` (et non `lue`)', () {
      final n = AppNotification.fromJson({
        'id': 1, 'titre': 'T', 'message': 'M', 'type': 'cotisation', 'lu': true,
      });
      expect(n.lue, isTrue);
    });

    test('DashboardData lit les rappels de cotisation et stats perso', () {
      final d = DashboardData.fromJson({
        'total_tontines': 1, 'total_membres': 3, 'total_collecte': 0,
        'urgences_en_cours': 0, 'total_cotise': 25000, 'montant_du_mois': 10000,
        'rappels_cotisation': [
          {'tontine_id': 2, 'tontine_nom': 'T', 'parts': 2, 'montant': 10000},
        ],
        'activites_recentes': [],
      });
      expect(d.totalCotise, 25000);
      expect(d.montantDuMois, 10000);
      expect(d.rappels, hasLength(1));
      expect(d.rappels.first.tontineNom, 'T');
      expect(d.rappels.first.montant, 10000);
    });
  });

  testWidgets('LoginScreen démarre sur l\'étape numéro', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Recevoir le code OTP'), findsOneWidget);
  });
}
