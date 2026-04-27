<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ReportController extends Controller
{
    public function index(Request $request)
    {
        $query = Report::query();

        if ($request->has('kecamatan')) {
            $query->byKecamatan($request->kecamatan);
        }

        if ($request->has('status')) {
            $query->byStatus($request->status);
        }

        if ($request->has('owner')) {
            $query->byOwner($request->owner);
        }

        $reports = $query->orderBy('created_at', 'desc')->get();

        return response()->json($reports);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'nama' => 'required|string',
            'jenis' => 'required|string',
            'deskripsi' => 'nullable|string',
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'severity' => 'required|numeric|min:1|max:5',
            'kecamatan' => 'required|string',
            'accuracy_meters' => 'nullable|numeric',
            'owner' => 'required|string',
            'foto_base64' => 'nullable|string',
            'status' => 'nullable|string|in:diterima,proses,selesai',
        ]);

        $id = Str::uuid()->toString();
        $fotoPath = null;

        if ($request->has('foto_base64') && $request->foto_base64) {
            $image = base64_decode($request->foto_base64);
            $filename = 'reports/' . $id . '.jpg';
            Storage::disk('public')->put($filename, $image);
            $fotoPath = $filename;
        }

        $report = Report::create([
            'id' => $id,
            'user_id' => $request->user()?->id,
            'nama' => $data['nama'],
            'jenis' => $data['jenis'],
            'deskripsi' => $data['deskripsi'] ?? '',
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
            'severity' => $data['severity'],
            'kecamatan' => $data['kecamatan'],
            'accuracy_meters' => $data['accuracy_meters'] ?? null,
            'owner' => $data['owner'],
            'foto_path' => $fotoPath,
            'status' => $data['status'] ?? 'diterima',
            'votes' => 0,
            'weather_risk' => 0,
        ]);

        return response()->json($report, 201);
    }

    public function show($id)
    {
        $report = Report::findOrFail($id);
        return response()->json($report);
    }

    public function updateStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:diterima,proses,selesai',
        ]);

        $report = Report::findOrFail($id);
        $report->update(['status' => $request->status]);

        return response()->json($report);
    }

    public function upvote($id)
    {
        $report = Report::findOrFail($id);
        $report->increment('votes');

        return response()->json($report);
    }

    public function destroy($id)
    {
        $report = Report::findOrFail($id);

        if ($report->foto_path) {
            Storage::disk('public')->delete($report->foto_path);
        }

        $report->delete();

        return response()->json(['message' => 'Deleted']);
    }
}

