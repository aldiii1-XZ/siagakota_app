<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'SiagaKota Admin')</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        primary: '#2563eb',
                        secondary: '#64748b',
                        success: '#22c55e',
                        warning: '#f59e0b',
                        danger: '#ef4444',
                    }
                }
            }
        }
    </script>
</head>
<body class="bg-gray-50 min-h-screen">
    @auth
    <nav class="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <a href="{{ route('admin.dashboard') }}" class="flex items-center gap-2">
                        <div class="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
                            <i class="fas fa-shield-alt text-white text-sm"></i>
                        </div>
                        <span class="font-bold text-xl text-gray-900">SiagaKota</span>
                    </a>
                    <div class="hidden md:flex ml-10 space-x-4">
                        <a href="{{ route('admin.dashboard') }}" class="px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.dashboard') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">
                            <i class="fas fa-chart-line mr-1"></i> Dashboard
                        </a>
                        <a href="{{ route('admin.reports') }}" class="px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.reports*') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">
                            <i class="fas fa-clipboard-list mr-1"></i> Laporan
                        </a>
                        <a href="{{ route('admin.users') }}" class="px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.users') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">
                            <i class="fas fa-users mr-1"></i> Pengguna
                        </a>
                        <a href="{{ route('admin.settings') }}" class="px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.settings') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">
                            <i class="fas fa-cog mr-1"></i> Pengaturan
                        </a>
                    </div>
                </div>
                <div class="flex items-center">
                    <span class="text-sm text-gray-600 mr-4 hidden sm:block">{{ Auth::user()->name }}</span>
                    <form action="{{ route('admin.logout') }}" method="POST" class="inline">
                        @csrf
                        <button type="submit" class="text-gray-500 hover:text-danger transition">
                            <i class="fas fa-sign-out-alt"></i>
                        </button>
                    </form>
                </div>
            </div>
        </div>
        <div class="md:hidden border-t border-gray-200">
            <div class="px-2 pt-2 pb-3 space-y-1">
                <a href="{{ route('admin.dashboard') }}" class="block px-3 py-2 rounded-md text-base font-medium {{ request()->routeIs('admin.dashboard') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">Dashboard</a>
                <a href="{{ route('admin.reports') }}" class="block px-3 py-2 rounded-md text-base font-medium {{ request()->routeIs('admin.reports*') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">Laporan</a>
                <a href="{{ route('admin.users') }}" class="block px-3 py-2 rounded-md text-base font-medium {{ request()->routeIs('admin.users') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">Pengguna</a>
                <a href="{{ route('admin.settings') }}" class="block px-3 py-2 rounded-md text-base font-medium {{ request()->routeIs('admin.settings') ? 'bg-primary text-white' : 'text-gray-700 hover:bg-gray-100' }}">Pengaturan</a>
            </div>
        </div>
    </nav>
    @endauth

    <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        @if(session('success'))
            <div class="mb-4 bg-success/10 border border-success/20 text-success px-4 py-3 rounded-lg">
                {{ session('success') }}
            </div>
        @endif

        @if($errors->any())
            <div class="mb-4 bg-danger/10 border border-danger/20 text-danger px-4 py-3 rounded-lg">
                <ul class="list-disc list-inside">
                    @foreach($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        @yield('content')
    </main>
</body>
</html>

