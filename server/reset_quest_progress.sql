-- Resets character quest progress so players can experience quests from the beginning.
-- Run against the live game database after making a database backup.

START TRANSACTION;

DELETE FROM `player_storage`;

DELETE FROM `kv_store`
WHERE `key_name` REGEXP '^player\\.[0-9]+\\.(tracker-new-quest|untracker-quest)$';

COMMIT;
