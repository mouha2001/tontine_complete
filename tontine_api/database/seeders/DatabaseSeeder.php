<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Tontine;
use App\Models\Cotisation;
use App\Models\Sutura;
use App\Models\SuturaVote;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ─── ADMIN ────────────────────────────────────────────────────────────
        $admin = User::create([
            'nom'                => 'Amadou Diallo',
            'telephone'          => '771234567',
            'email'              => 'admin@tontine.sn',
            'role'               => 'admin',
            'telephone_verified' => true,
            'adresse'            => 'Dakar, Sénégal',
        ]);

        // ─── MEMBRES ──────────────────────────────────────────────────────────
        $membres = collect([
            ['nom' => 'Fatou Sall',     'telephone' => '772345678'],
            ['nom' => 'Moussa Ndiaye',  'telephone' => '773456789'],
            ['nom' => 'Aïda Mbaye',     'telephone' => '774567890'],
            ['nom' => 'Omar Ba',        'telephone' => '775678901'],
            ['nom' => 'Khadija Diop',   'telephone' => '776789012'],
        ])->map(fn($data) => User::create([
            ...$data,
            'role'               => 'membre',
            'telephone_verified' => true,
        ]));

        // ─── TONTINE ACTIVE ───────────────────────────────────────────────────
        $tontine = Tontine::create([
            'admin_id'           => $admin->id,
            'nom'                => 'Famille Diallo',
            'description'        => 'Tontine mensuelle de la famille Diallo',
            'montant_cotisation' => 25000,
            'frequence'          => 'mensuel',
            'nombre_membres'     => 6,
            'statut'             => 'active',
            'date_debut'         => now()->subMonth(),
            'tour_actuel'        => 1,
        ]);

        // Ajouter tous les membres + l'admin
        $tontine->membres()->attach($admin->id);
        foreach ($membres as $membre) {
            $tontine->membres()->attach($membre->id);
        }

        // ─── COTISATIONS CONFIRMÉES ───────────────────────────────────────────
        foreach ([$admin, ...$membres->take(3)->all()] as $u) {
            Cotisation::create([
                'tontine_id'       => $tontine->id,
                'user_id'          => $u->id,
                'montant'          => 25000,
                'statut'           => 'confirme',
                'methode_paiement' => $u->id % 2 === 0 ? 'wave' : 'orange_money',
                'reference'        => 'TON-' . strtoupper(str()->random(10)),
                'paye_le'          => now()->subDays(rand(1, 20)),
            ]);
        }

        // ─── SUTURA EN COURS ──────────────────────────────────────────────────
        $sutura = Sutura::create([
            'tontine_id'     => $tontine->id,
            'demandeur_id'   => $membres->first()->id,
            'montant_demande' => 15000,
            'motif'          => 'Frais médicaux urgents pour un enfant hospitalisé',
            'statut'         => 'en_cours',
        ]);

        // Quelques votes
        SuturaVote::create(['sutura_id' => $sutura->id, 'user_id' => $admin->id, 'approuve' => true]);
        SuturaVote::create(['sutura_id' => $sutura->id, 'user_id' => $membres[1]->id, 'approuve' => true]);
        SuturaVote::create(['sutura_id' => $sutura->id, 'user_id' => $membres[2]->id, 'approuve' => false]);

        // ─── 2ème TONTINE ─────────────────────────────────────────────────────
        $tontine2 = Tontine::create([
            'admin_id'           => $admin->id,
            'nom'                => 'Collègues Bureau',
            'description'        => 'Tontine hebdomadaire des collègues',
            'montant_cotisation' => 10000,
            'frequence'          => 'hebdomadaire',
            'nombre_membres'     => 4,
            'statut'             => 'en_attente',
        ]);

        $tontine2->membres()->attach($admin->id);
        $tontine2->membres()->attach($membres[0]->id);
        $tontine2->membres()->attach($membres[1]->id);

        $this->command->info('✅ Données de test créées !');
        $this->command->table(
            ['Rôle', 'Nom', 'Téléphone'],
            [
                ['Admin', $admin->nom, $admin->telephone],
                ...collect($membres)->map(fn($m) => ['Membre', $m->nom, $m->telephone])->toArray(),
            ]
        );
        $this->command->info('💡 OTP démo (en dev) : tous les codes sont logués dans storage/logs/laravel.log');
    }
}
