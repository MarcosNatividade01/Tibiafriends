-- Give all existing and future accounts 99,999,999 regular and transferable Tibia Coins.
-- The store/client can check either balance depending on offer type and protocol.
ALTER TABLE `accounts`
    MODIFY `coins` int(12) UNSIGNED NOT NULL DEFAULT 99999999,
    MODIFY `coins_transferable` int(12) UNSIGNED NOT NULL DEFAULT 99999999;

UPDATE `accounts`
SET
    `coins` = GREATEST(`coins`, 99999999),
    `coins_transferable` = GREATEST(`coins_transferable`, 99999999);

-- Remove the old per-character bonus so creating characters cannot stack coins.
DROP TRIGGER IF EXISTS `after_player_created_grant_coins`;
