<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\MetaController;
use App\Http\Controllers\Api\ReportController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', [AuthController::class, 'profile']);

    Route::get('/reports', [ReportController::class, 'index']);
    Route::post('/reports', [ReportController::class, 'store']);
    Route::get('/reports/{id}', [ReportController::class, 'show']);
    Route::put('/reports/{id}/status', [ReportController::class, 'updateStatus']);
    Route::post('/reports/{id}/upvote', [ReportController::class, 'upvote']);
    Route::delete('/reports/{id}', [ReportController::class, 'destroy']);

    Route::get('/meta', [MetaController::class, 'show']);
    Route::post('/meta', [MetaController::class, 'storeOrUpdate']);
});

