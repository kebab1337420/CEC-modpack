managers.enemy.force_spawned = 0
Hooks:PostHook(EnemyManager, "on_enemy_registered", "BAI_EnemyManager_on_enemy_registered", function(self, ...)
    self.force_spawned = self.force_spawned + 1
end)