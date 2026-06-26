-- Give all existing and future accounts 99,999,999 regular Tibia Coins.
-- The GameStore defaults to regular Tibia Coins for offers without an explicit coinType.
ALTER TABLE `accounts`
    MODIFY `coins` int(12) UNSIGNED NOT NULL DEFAULT 99999999;

UPDATE `accounts`
SET `coins` = 99999999
WHERE `coins` < 99999999;

-- Remove the old per-character bonus so creating characters cannot stack coins.
DROP TRIGGER IF EXISTS `after_player_created_grant_coins`;
