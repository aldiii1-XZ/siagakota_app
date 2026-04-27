<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AppMeta extends Model
{
    protected $table = 'app_meta';

    protected $fillable = [
        'key', 'latest_version', 'note', 'apk_url', 'force_update',
    ];

    protected $casts = [
        'force_update' => 'boolean',
    ];
}

