-- Migration to drop unused heater_activation_temp column

ALTER TABLE devices
DROP COLUMN IF EXISTS heater_activation_temp;
