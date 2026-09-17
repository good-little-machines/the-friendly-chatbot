<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Override;

#[Fillable(['name','slug'])]
class Team extends Model
{
    use SoftDeletes;

    #[Override]
    public function getRouteKeyName(): string
    {
        return "slug";
    }

}
