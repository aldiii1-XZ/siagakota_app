<?php

use App\Http\Controllers\WebAdminController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect('/admin/login');
});

Route::get('/admin/login', [WebAdminController::class, 'loginForm'])->name('admin.login');
Route::post('/admin/login', [WebAdminController::class, 'login']);

Route::middleware('auth')->prefix('admin')->group(function () {
    Route::post('/logout', [WebAdminController::class, 'logout'])->name('admin.logout');
    Route::get('/dashboard', [WebAdminController::class, 'dashboard'])->name('admin.dashboard');
    Route::get('/reports', [WebAdminController::class, 'reports'])->name('admin.reports');
    Route::get('/reports/{id}', [WebAdminController::class, 'reportDetail'])->name('admin.report.detail');
    Route::put('/reports/{id}/status', [WebAdminController::class, 'updateReportStatus'])->name('admin.report.status');
    Route::delete('/reports/{id}', [WebAdminController::class, 'deleteReport'])->name('admin.report.delete');
    Route::get('/users', [WebAdminController::class, 'users'])->name('admin.users');
    Route::get('/settings', [WebAdminController::class, 'settings'])->name('admin.settings');
    Route::put('/settings', [WebAdminController::class, 'updateSettings'])->name('admin.settings.update');
});
