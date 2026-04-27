<?php

namespace App\Http\Controllers;

use App\Models\Report;
use App\Models\User;
use App\Models\AppMeta;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class WebAdminController extends Controller
{
    public function loginForm()
    {
        return view('admin.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        if (Auth::attempt($credentials)) {
            $request->session()->regenerate();
            return redirect()->intended('/admin/dashboard');
        }

        return back()->withErrors([
            'email' => 'Email atau password salah.',
        ]);
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        return redirect('/admin/login');
    }

    public function dashboard()
    {
        $total = Report::count();
        $diterima = Report::byStatus('diterima')->count();
        $proses = Report::byStatus('proses')->count();
        $selesai = Report::byStatus('selesai')->count();

        $topKecamatan = Report::selectRaw('kecamatan, COUNT(*) as count')
            ->groupBy('kecamatan')
            ->orderByDesc('count')
            ->limit(5)
            ->get();

        $recentReports = Report::orderBy('created_at', 'desc')->limit(10)->get();

        return view('admin.dashboard', compact('total', 'diterima', 'proses', 'selesai', 'topKecamatan', 'recentReports'));
    }

    public function reports(Request $request)
    {
        $query = Report::query();

        if ($request->filled('status')) {
            $query->byStatus($request->status);
        }

        if ($request->filled('kecamatan')) {
            $query->byKecamatan($request->kecamatan);
        }

        if ($request->filled('search')) {
            $query->where(function ($q) use ($request) {
                $q->where('nama', 'like', '%' . $request->search . '%')
                  ->orWhere('deskripsi', 'like', '%' . $request->search . '%')
                  ->orWhere('jenis', 'like', '%' . $request->search . '%');
            });
        }

        $reports = $query->orderBy('created_at', 'desc')->paginate(20);
        $kecamatanList = Report::select('kecamatan')->distinct()->pluck('kecamatan');

        return view('admin.reports', compact('reports', 'kecamatanList'));
    }

    public function reportDetail($id)
    {
        $report = Report::findOrFail($id);
        return view('admin.report_detail', compact('report'));
    }

    public function updateReportStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:diterima,proses,selesai',
        ]);

        $report = Report::findOrFail($id);
        $report->update(['status' => $request->status]);

        return redirect()->back()->with('success', 'Status laporan diperbarui.');
    }

    public function deleteReport($id)
    {
        $report = Report::findOrFail($id);
        $report->delete();

        return redirect()->route('admin.reports')->with('success', 'Laporan dihapus.');
    }

    public function users()
    {
        $users = User::orderBy('created_at', 'desc')->paginate(20);
        return view('admin.users', compact('users'));
    }

    public function settings()
    {
        $meta = AppMeta::where('key', 'app')->first();
        return view('admin.settings', compact('meta'));
    }

    public function updateSettings(Request $request)
    {
        $data = $request->validate([
            'latest_version' => 'required|string',
            'note' => 'nullable|string',
            'apk_url' => 'nullable|string',
            'force_update' => 'boolean',
        ]);

        AppMeta::updateOrCreate(['key' => 'app'], $data);

        return redirect()->back()->with('success', 'Pengaturan diperbarui.');
    }
}

