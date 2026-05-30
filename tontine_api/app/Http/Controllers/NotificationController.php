<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $notifications = $request->user()
            ->notifications()
            ->orderByDesc('created_at')
            ->limit(50)
            ->get()
            ->map(fn($n) => [
                'id'         => $n->id,
                'type'       => $n->type,
                'titre'      => $n->titre,
                'message'    => $n->message,
                'data'       => $n->data,
                'lu'         => $n->lu,
                'created_at' => $n->created_at->toISOString(),
            ]);

        return response()->json(['data' => $notifications]);
    }

    public function marquerLue(Request $request, int $id): JsonResponse
    {
        $notif = Notification::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $notif->update(['lu' => true]);

        return response()->json(['message' => 'Notification marquée comme lue']);
    }

    public function marquerToutesLues(Request $request): JsonResponse
    {
        $request->user()->notifications()->update(['lu' => true]);
        return response()->json(['message' => 'Toutes les notifications marquées comme lues']);
    }

    public function enregistrerFcmToken(Request $request): JsonResponse
    {
        $request->validate(['token' => 'required|string']);

        $request->user()->update(['fcm_token' => $request->token]);

        return response()->json(['message' => 'Token FCM enregistré']);
    }

    public function nbNonLues(Request $request): JsonResponse
    {
        $count = $request->user()->notifications()->where('lu', false)->count();
        return response()->json(['count' => $count]);
    }
}
