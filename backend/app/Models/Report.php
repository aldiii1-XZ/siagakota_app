<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Report extends Model
{
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id', 'user_id', 'nama', 'jenis', 'deskripsi',
        'latitude', 'longitude', 'severity', 'kecamatan',
        'foto_path', 'accuracy_meters', 'status', 'votes',
        'duplicate_of', 'weather_risk', 'owner',
    ];

    protected $casts = [
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
        'severity' => 'decimal:1',
        'accuracy_meters' => 'float',
        'weather_risk' => 'decimal:2',
        'votes' => 'integer',
        'force_update' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopeByKecamatan($query, $kecamatan)
    {
        return $query->where('kecamatan', $kecamatan);
    }

    public function scopeByStatus($query, $status)
    {
        return $query->where('status', $status);
    }

    public function scopeByOwner($query, $owner)
    {
        return $query->where('owner', $owner);
    }
}

