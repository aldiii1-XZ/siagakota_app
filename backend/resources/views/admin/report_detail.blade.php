@extends('layouts.admin')

@section('title', 'Detail Laporan - SiagaKota')

@section('content')
<div class="max-w-4xl mx-auto space-y-6">
    <div class="flex items-center gap-2 text-sm text-gray-500 mb-4">
        <a href="{{ route('admin.reports') }}" class="hover:text-primary">Laporan</a>
        <i class="fas fa-chevron-right text-xs"></i>
        <span>Detail</span>
    </div>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <div>
                <h1 class="text-xl font-bold text-gray-900">{{ $report->jenis }}</h1>
                <p class="text-gray-500 text-sm mt-1">ID: {{ $report->id }}</p>
            </div>
            <span class="px-3 py-1 rounded-full text-sm font-medium self-start
                @if($report->status == 'diterima') bg-amber-100 text-amber-700
                @elseif($report->status == 'proses') bg-blue-100 text-blue-700
                @else bg-green-100 text-green-700 @endif">
                {{ ucfirst($report->status) }}
            </span>
        </div>

        <div class="p-6 space-y-6">
            @if($report->foto_path)
            <div>
                <h3 class="text-sm font-medium text-gray-700 mb-2">Foto</h3>
                <img src="{{ asset('storage/' . $report->foto_path) }}" alt="Foto Laporan" class="rounded-lg max-h-80 object-cover">
            </div>
            @endif

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Nama Pelapor</label>
                    <p class="text-gray-900 mt-1">{{ $report->nama }}</p>
                </div>
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Owner</label>
                    <p class="text-gray-900 mt-1">{{ $report->owner }}</p>
                </div>
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Kecamatan</label>
                    <p class="text-gray-900 mt-1">{{ $report->kecamatan }}</p>
                </div>
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Severity</label>
                    <p class="text-gray-900 mt-1">{{ $report->severity }} / 5</p>
                </div>
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Koordinat</label>
                    <p class="text-gray-900 mt-1">{{ $report->latitude }}, {{ $report->longitude }}</p>
                </div>
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Akurasi</label>
                    <p class="text-gray-900 mt-1">{{ $report->accuracy_meters ? round($report->accuracy_meters, 1) . ' m' : '-' }}</p>
                </div>
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Dukungan</label>
                    <p class="text-gray-900 mt-1">{{ $report->votes }} votes</p>
                </div>
                <div>
                    <label class="text-xs font-medium text-gray-500 uppercase">Dibuat</label>
                    <p class="text-gray-900 mt-1">{{ $report->created_at->format('d M Y H:i') }}</p>
                </div>
            </div>

            <div>
                <label class="text-xs font-medium text-gray-500 uppercase">Deskripsi</label>
                <p class="text-gray-900 mt-1 whitespace-pre-line">{{ $report->deskripsi ?: '-' }}</p>
            </div>

            <div class="border-t border-gray-100 pt-6">
                <h3 class="text-sm font-medium text-gray-700 mb-3">Ubah Status</h3>
                <form action="{{ route('admin.report.status', $report->id) }}" method="POST" class="flex flex-wrap gap-2">
                    @csrf
                    @method('PUT')
                    <button type="submit" name="status" value="diterima"
                            class="px-4 py-2 rounded-lg text-sm font-medium border transition
                            {{ $report->status == 'diterima' ? 'bg-amber-100 border-amber-300 text-amber-700' : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50' }}">
                        Diterima
                    </button>
                    <button type="submit" name="status" value="proses"
                            class="px-4 py-2 rounded-lg text-sm font-medium border transition
                            {{ $report->status == 'proses' ? 'bg-blue-100 border-blue-300 text-blue-700' : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50' }}">
                        Proses
                    </button>
                    <button type="submit" name="status" value="selesai"
                            class="px-4 py-2 rounded-lg text-sm font-medium border transition
                            {{ $report->status == 'selesai' ? 'bg-green-100 border-green-300 text-green-700' : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50' }}">
                        Selesai
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>
@endsection

