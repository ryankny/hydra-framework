-- ============================================
-- Hydra Framework - Database Schema
-- ============================================
-- Run this SQL file to set up all required tables.
-- Hydra also auto-creates tables on first boot if
-- auto_migrate is enabled (default: true).
-- ============================================

-- Players table
CREATE TABLE IF NOT EXISTS `hydra_players` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `last_name` VARCHAR(64) DEFAULT NULL,
  `permission_group` VARCHAR(32) DEFAULT 'user',
  `accounts` LONGTEXT DEFAULT '{}',
  `job` TEXT DEFAULT '{}',
  `position` TEXT DEFAULT '{}',
  `metadata` LONGTEXT DEFAULT '{}',
  `charinfo` TEXT DEFAULT '{}',
  `inventory` LONGTEXT DEFAULT '{}',
  `last_login` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `idx_identifier` (`identifier`),
  INDEX `idx_permission_group` (`permission_group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Optional: Migration from ESX
-- ============================================
-- Uncomment the following to migrate existing ESX users:
--
-- INSERT INTO hydra_players (identifier, last_name, permission_group, accounts, job, position, metadata)
-- SELECT
--   u.identifier,
--   u.lastname,
--   COALESCE(u.group, 'user'),
--   CONCAT('{"cash":', COALESCE(u.money, 0), ',"bank":', COALESCE(u.bank, 0), ',"black_money":', COALESCE(u.black_money, 0), '}'),
--   CONCAT('{"name":"', COALESCE(u.job, 'unemployed'), '","grade":', COALESCE(u.job_grade, 0), '}'),
--   COALESCE(u.position, '{}'),
--   '{}'
-- FROM users u
-- ON DUPLICATE KEY UPDATE last_name = VALUES(last_name);

-- ============================================
-- Optional: Migration from QBCore
-- ============================================
-- Uncomment the following to migrate existing QBCore players:
--
-- INSERT INTO hydra_players (identifier, last_name, permission_group, accounts, job, position, charinfo, metadata)
-- SELECT
--   p.citizenid,
--   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')),
--   'user',
--   p.money,
--   p.job,
--   p.position,
--   p.charinfo,
--   p.metadata
-- FROM players p
-- ON DUPLICATE KEY UPDATE last_name = VALUES(last_name);
