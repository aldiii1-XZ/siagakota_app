@extends('layouts.admin')

@section('title', 'Login Admin - SiagaKota')

@section('content')
<div class="min-h-[80vh] flex items-center justify-center">
    <div class="w-full max-w-md">
        <div class="bg-white rounded-2xl shadow-lg p-8">
            <div class="text-center mb-8">
                <div class="w-16 h-16 bg-primary rounded-xl flex items-center justify-center mx-auto mb-4">
                    <i class="fas fa-shield-alt text-white text-2xl"></i>
                </div>
                <h1 class="text-2xl font-bold text-gray-900">SiagaKota Admin</h1>
                <p class="text-gray-500 mt-1">Masuk ke panel administrasi</p>
            </div>

            <form action="{{ url('/admin/login') }}" method="POST" class="space-y-5">
                @csrf
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                    <input type="email" name="email" required
                           class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary transition"
                           placeholder="admin@siagakota.id">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
                    <input type="password" name="password" required
                           class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary transition"
                           placeholder="••••••••">
                </div>
                <button type="submit"
                        class="w-full bg-primary hover:bg-blue-700 text-white font-medium py-2.5 rounded-lg transition duration-200">
                    Masuk
                </button>
            </form>
        </div>
    </div>
</div>
@endsection

