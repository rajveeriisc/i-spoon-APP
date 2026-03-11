import { z } from 'zod';

export const registerDeviceSchema = z.object({
    macAddressHash: z.string().min(8, 'macAddressHash too short').max(128, 'macAddressHash too long'),
    firmwareVersion: z.string().max(32).optional(),
    heaterActive: z.union([z.boolean(), z.string().transform(val => val === 'true')]).optional().default(false),
    heaterMaxTemp: z.coerce.number().min(30).max(95).optional().default(40.0),
});

export const updateDeviceSettingsSchema = z.object({
    heaterActive: z.union([z.boolean(), z.string().transform(val => val === 'true')]).optional(),
    heaterMaxTemp: z.coerce.number().min(30).max(95).optional(),
});
