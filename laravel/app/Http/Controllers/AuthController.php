<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Tontine;
use App\Services\OtpService;
use App\Services\NotificationService;
use App\Services\TontineMembershipService;
use App\Support\Phone;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class AuthController extends Controller
{
    public function __construct(
        private OtpService $otpService,
        private NotificationService $notifService,
    ) {}

    // ─── 1. ENVOYER OTP ───────────────────────────────────────────────────────
    public function sendOtp(Request $request): JsonResponse
    {
        $request->validate([
            'telephone' => 'required|string|min:9|max:15',
            'role'      => 'required|in:admin,membre',
        ]);

        $phone = $this->normalizePhone($request->telephone);

        // Créer ou retrouver l'utilisateur
        $user = User::firstOrCreate(
            ['telephone' => $phone],
            ['nom' => 'Utilisateur', 'role' => $request->role],
        );

        $otp = $user->generateOtp();

        try {
            $this->otpService->send($phone, $otp);
        } catch (\Throwable $e) {
            return response()->json([
                'message' => "Échec de l'envoi du SMS, veuillez réessayer",
            ], 502);
        }

        return response()->json([
            'message' => 'Code OTP envoyé avec succès',
            'expires_in' => 600, // 10 minutes
        ]);
    }

    // ─── 2. VÉRIFIER OTP + CONNEXION ─────────────────────────────────────────
    public function verifyOtp(Request $request, TontineMembershipService $membership): JsonResponse
    {
        $request->validate([
            'telephone'   => 'required|string',
            'otp'         => 'required|string|size:6',
            'role'        => 'required|in:admin,membre',
            'prenom'      => 'nullable|string|max:100',
            'nom'         => 'nullable|string|max:100',
            'invite_code' => 'nullable|string',
        ]);

        $phone = $this->normalizePhone($request->telephone);
        $user  = User::where('telephone', $phone)->firstOrFail();

        if (!$user->verifyOtp($request->otp)) {
            return response()->json([
                'message' => 'Code OTP invalide ou expiré',
            ], 422);
        }

        $joinResult = null;

        // Compte jamais finalisé (telephone_verified = false) → inscription requise.
        // On exige prénom + nom ; tant qu'ils manquent, on NE supprime PAS l'OTP
        // afin que le second appel (avec le profil) reste valide.
        if (!$user->telephone_verified) {
            if (!$request->filled('prenom') || !$request->filled('nom')) {
                return response()->json([
                    'message'            => 'Compte introuvable, complétez votre profil',
                    'needs_registration' => true,
                ]);
            }

            // Finalisation de l'inscription
            $user->update([
                'prenom' => $request->prenom,
                'nom'    => $request->nom,
                'role'   => $request->role,
            ]);

            // Code d'invitation fourni à l'inscription → rejoint la tontine directement.
            // Échec (code invalide / pleine) = non bloquant : le compte est créé quand même.
            if ($request->filled('invite_code')) {
                $tontine = Tontine::where('invite_code', $request->invite_code)->first();
                if ($tontine) {
                    $res = $membership->join($tontine, $user);
                    $joinResult = [
                        'ok'      => $res['ok'],
                        'message' => $res['message'],
                        'tontine' => $res['ok'] ? $tontine->nom : null,
                    ];
                } else {
                    $joinResult = ['ok' => false, 'message' => 'Code d\'invitation invalide', 'tontine' => null];
                }
            }
        }
        // Compte existant → simple connexion, on ne touche ni au profil ni au rôle.

        $user->clearOtp();

        // Révoquer les anciens tokens et en créer un nouveau
        $user->tokens()->delete();
        $token = $user->createToken('tontine-app')->accessToken;

        return response()->json([
            'message' => 'Connexion réussie',
            'token'   => $token,
            'user'    => $user->toApiArray(),
            'join'    => $joinResult,
        ]);
    }

    // ─── 3. INSCRIPTION ADMIN COMPLÈTE ────────────────────────────────────────
    public function registerAdmin(Request $request): JsonResponse
    {
        $request->validate([
            'nom'       => 'required|string|max:100',
            'prenom'    => 'nullable|string|max:100',
            'telephone' => 'required|string',
            'otp'       => 'required|string|size:6',
            'email'     => 'nullable|email|unique:users',
            'adresse'   => 'nullable|string|max:255',
        ]);

        $phone = $this->normalizePhone($request->telephone);
        $user  = User::where('telephone', $phone)->firstOrFail();

        if (!$user->verifyOtp($request->otp)) {
            return response()->json(['message' => 'Code OTP invalide ou expiré'], 422);
        }

        $user->update([
            'nom'     => $request->nom,
            'prenom'  => $request->prenom,
            'role'    => 'admin',
            'email'   => $request->email,
            'adresse' => $request->adresse,
        ]);
        $user->clearOtp();

        $user->tokens()->delete();
        $token = $user->createToken('tontine-app')->accessToken;

        return response()->json([
            'message' => 'Compte administrateur créé',
            'token'   => $token,
            'user'    => $user->toApiArray(),
        ], 201);
    }

    // ─── 4. REJOINDRE VIA INVITATION ──────────────────────────────────────────
    public function joinViaInvite(Request $request): JsonResponse
    {
        $request->validate([
            'invite_code' => 'required|string',
            'telephone'   => 'required|string',
            'otp'         => 'required|string|size:6',
            'nom'         => 'required|string|max:100',
            'prenom'      => 'nullable|string|max:100',
        ]);

        $tontine = Tontine::where('invite_code', $request->invite_code)->first();
        if (!$tontine) {
            return response()->json(['message' => 'Code d\'invitation invalide'], 404);
        }

        if ($tontine->membres_actuels >= $tontine->nombre_membres) {
            return response()->json(['message' => 'La tontine est complète'], 422);
        }

        $phone = $this->normalizePhone($request->telephone);
        $user  = User::where('telephone', $phone)->firstOrFail();

        if (!$user->verifyOtp($request->otp)) {
            return response()->json(['message' => 'Code OTP invalide ou expiré'], 422);
        }

        $user->update(['nom' => $request->nom, 'prenom' => $request->prenom, 'role' => 'membre']);
        $user->clearOtp();

        // Ajouter à la tontine si pas déjà membre
        if (!$tontine->membres()->where('user_id', $user->id)->exists()) {
            $tontine->membres()->attach($user->id);

            // Notifier l'admin
            $this->notifService->send(
                $tontine->admin_id,
                'nouveau_membre',
                'Nouveau membre',
                "{$user->nom} a rejoint la tontine {$tontine->nom}",
                ['tontine_id' => $tontine->id],
            );
        }

        $user->tokens()->delete();
        $token = $user->createToken('tontine-app')->accessToken;

        return response()->json([
            'message' => 'Vous avez rejoint la tontine avec succès',
            'token'   => $token,
            'user'    => $user->toApiArray(),
        ]);
    }

    // ─── 5. PROFIL COURANT ────────────────────────────────────────────────────
    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $request->user()->toApiArray(),
        ]);
    }

    // ─── 6. DÉCONNEXION ───────────────────────────────────────────────────────
    public function logout(Request $request): JsonResponse
    {
        $request->user()->token()->revoke();
        return response()->json(['message' => 'Déconnecté avec succès']);
    }

    // ─── HELPER ───────────────────────────────────────────────────────────────
    private function normalizePhone(string $phone): string
    {
        return Phone::normalize($phone);
    }
}
