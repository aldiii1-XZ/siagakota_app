@extends('layouts.admin')

@section('title', 'Dashboard - SiagaKota')

@section('content')
<div class="space-y-6">
    <div>
        <h1 class="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p class="text-gray-500 mt-1">Ringkasan data laporan SiagaKota</p>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-500">Total Laporan</p>
                    <p class="text-3xl font-bold text-gray-900 mt-1">{{ $total }}</p>
                </div>
                <div class="w-12 h-12 bg-blue-50 rounded-lg flex items-center justify-center">
                    <i class="fas fa-clipboard-list text-primary text-xl"></i>
                </div>
            </div>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-500">Diterima</p>
                    <p class="text-3xl font-bold text-warning mt-1">{{ $diterima }}</p>
                </div>
                <div class="w-12 h-12 bg-amber-50 rounded-lg flex items-center justify-center">
                    <i class="fas fa-hourglass-half text-warning text-xl"></i>
                </div>
            </div>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-500">Proses</p>
                    <p class="text-3xl font-bold text-primary mt-1">{{ $proses }}</p>
                </div>
                <div class="w-12 h-12 bg-blue-50 rounded-lg flex items-center justify-center">
                    <i class="fas fa-cogs text-primary text-xl"></i>
                </div>
            </div>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-500">Selesai</p>
                    <p class="text-3xl font-bold text-success mt-1">{{ $selesai }}</p>
                </div>
                <div class="w-12 h-12 bg-green-50 rounded-lg flex items-center justify-center">
                    <i class="fas fa-check-circle text-success text-xl"></i>
                </div>
            </div>
        </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
            <div class="px-6 py-4 border-b border-gray-100">
                <h3 class="font-semibold text-gray-900">Top Kecamatan</h3>
            </div>
            <div class="p-6">
                @if($topKecamatan->isEmpty())
                    <p class="text-gray-500 text-center py-4">Belum ada data</p>
                @else
                    <div class="space-y-3">
                        @foreach($topKecamatan as $k)
                        <div class="flex items-center justify-between">
                            <span class="text-gray-700">{{ $k->kecamatan }}</span>
                            <span class="bg-gray-100 text-gray-700 px-3 py-1 rounded-full text-sm font-medium">{{ $k->count }} laporan</span>
                        </div>
                        @endforeach
                    </div>
                @endif
            </div>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
            <div class="px-6 py-4 border-b border-gray-100 flex justify-between items-center">
                <h3 class="font-semibold text-gray-900">Laporan Terbaru</h3>
                <a href="{{ route('admin.reports') }}" class="text-primary text-sm hover:underline">Lihat semua</a>
            </div>
            <div class="divide-y divide-gray-100">
                @forelse($recentReports as $report)
                <div class="px-6 py-4 hover:bg-gray-50 transition">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="font-medium text-gray-900">{{ $report->jenis }}</p>
                            <p class="text-sm text-gray-500">{{ $report->kecamatan }} • {{ $report->created_at->diffForHumans() }}</p>
                        </div>
                        <span class="px-2.5 py-1 rounded-full text-xs font-medium
                            @if($report->status == 'diterima') bg-amber-100 text-amber-700
                            @elseif($report->status == 'proses') bg-blue-100 text-blue-700
                            @else bg-green-100 text-green-700 @endif">
                            {{ ucfirst($report->status) }}
                        </span>
                    </div>
                </div>
                @empty
                <div class="px-6 py-8 text-center text-gray-500">Belum ada laporan</div>
                @endforelse
            </div>
        </div>
    </div>
</div>
@endsection

