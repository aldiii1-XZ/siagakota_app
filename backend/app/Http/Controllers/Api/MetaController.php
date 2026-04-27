<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppMeta;
use Illuminate\Http\Request;

class MetaController extends Controller
{
    public function show()
    {
        $meta = AppMeta::where('key', 'app')->first();

        if (! $meta) {
            return response()->json([
                'latestVersion' => '1.0.0',
                'note' => 'Versi terbaru tersedia.',
                'apkUrl' => null,
                'forceUpdate' => false,
            ]);
        }

        return response()->json([
            'latestVersion' => $meta->latest_version,
            'note' => $meta->note,
            'apkUrl' => $meta->apk_url,
            'forceUpdate' => $meta->force_update,
        ]);
    }

    public function storeOrUpdate(Request $request)
    {
        $data = $request->validate([
            'latest_version' => 'required|string',
            'note' => 'nullable|string',
            'apk_url' => 'nullable|string',
            'force_update' => 'boolean',
        ]);

        $meta = AppMeta::updateOrCreate(
            ['key' => 'app'],
            $data
        );

        return response()->json($meta);
    }
}

