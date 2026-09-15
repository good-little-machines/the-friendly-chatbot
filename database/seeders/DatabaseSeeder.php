<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        User::factory()->create([
            'name' => 'Alex Test',
            'email' => 'alex@example.com',
        ]);

        User::factory()->create([
            'name' => 'Leah Test',
            'email' => 'leah@example.com',
        ]);
    }
}
