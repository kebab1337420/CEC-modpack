if BAI:CheckLoadHook("EnemyManager") then
    return
end

function EnemyManager:GetNumberOfEnemies()
    return self._enemy_data.nr_units
end