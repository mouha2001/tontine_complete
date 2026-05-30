<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Tontine;
use App\Services\OtpService;
use App\Services\NotificationService;
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
        $this->otpService->send($phone, $otp);

        return response()->json([
            'message' => 'Code OTP envoyé avec succès',
            'expires_in' => 600, // 10 minutes
        ]);
    }

    // ─── 2. VÉRIFIER OTP + CONNEXION ─────────────────────────────────────────
    public function verifyOtp(Request $request): JsonResponse
    {
        $request->validate([
            'telephone' => 'required|string',
            'otp'       => 'required|string|size:6',
            'role'      => 'required|in:admin,membre',
            'nom'       => 'nullable|string|max:100',
        ]);

        $phone = $this->normalizePhone($request->telephone);
        $user  = User::where('telephone', $phone)->firstOrFail();

        if (!$user->verifyOtp($request->otp)) {
            return response()->json([
                'message' => 'Code OTP invalide ou expiré',
            ], 422);
        }

        // Mettre à jour le nom si fourni (inscription)
        if ($request->filled('nom')) {
            $user->update(['nom' => $request->nom]);
        }

        // Mettre à jour le rôle si nécessaire
        if ($user->role !== $request->role) {
            $user->update(['role' => $request->role]);
        }

        $user->clearOtp();

        // Révoquer les anciens tokens et en créer un nouveau
        $user->tokens()->delete();
        $token = $user->createToken('tontine-app')->accessToken;

        return response()->json([
            'message' => 'Connexion réussie',
            'token'   => $token,
            'user'    => $user->toApiArray(),
        ]);
    }

    // ─── 3. INSCRIPTION ADMIN COMPLÈTE ────────────────────────────────────────
    public function registerAdmin(Request $request): JsonResponse
    {
        $request->validate([
            'nom'       => 'required|string|max:100',
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

        $user->update(['nom' => $request->nom, 'role' => 'membre']);
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
        // Retirer espaces et préfixe +221
        $phone = preg_replace('/\s+/', '', $phone);
        $phone = ltrim($phone, '+');
        if (str_starts_with($phone, '221')) {
            $phone = substr($phone, 3);
        }
        return $phone;
    }
}
