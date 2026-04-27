@extends('layouts.admin')

@section('title', 'Pengaturan - SiagaKota')

@section('content')
<div class="max-w-2xl mx-auto space-y-6">
    <div>
        <h1 class="text-2xl font-bold text-gray-900">Pengaturan Aplikasi</h1>
        <p class="text-gray-500 mt-1">Kelola informasi update aplikasi mobile</p>
    </div>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100">
        <form action="{{ route('admin.settings.update') }}" method="POST" class="p-6 space-y-5">
            @csrf
            @method('PUT')

            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Versi Terbaru</label>
                <input type="text" name="latest_version" value="{{ old('latest_version', $meta?->latest_version ?? '1.0.0') }}"
                       class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary"
                       placeholder="1.0.0">
            </div>

            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Catatan Rilis</label>
                <textarea name="note" rows="3"
                          class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary"
                          placeholder="Deskripsi update...">{{ old('note', $meta?->note) }}</textarea>
            </div>

            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">URL APK</label>
                <input type="url" name="apk_url" value="{{ old('apk_url', $meta?->apk_url) }}"
                       class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary"
                       placeholder="https://example.com/app.apk">
            </div>

            <div class="flex items-center gap-3">
                <input type="checkbox" name="force_update" id="force_update" value="1"
                       {{ old('force_update', $meta?->force_update ?? false) ? 'checked' : '' }}
                       class="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary">
                <label for="force_update" class="text-sm font-medium text-gray-700">Wajib Update</label>
            </div>

            <div class="pt-4">
                <button type="submit" class="px-6 py-2.5 bg-primary text-white font-medium rounded-lg hover:bg-blue-700 transition">
                    Simpan Pengaturan
                </button>
            </div>
        </form>
    </div>
</div>
@endsection

