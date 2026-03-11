import { z } from 'zod';

const biteSchema = z.object({
    meal_uuid: z.string().optional(),
    timestamp: z.string().datetime("Invalid ISO datetime for timestamp"),
    sequence_number: z.number().int().min(0).max(100000).optional().nullable(),
    tremor_magnitude: z.number().min(0).max(1000).optional().nullable(),
    tremor_frequency: z.number().min(0).max(100).optional().nullable(),
    food_temp_c: z.number().min(-10).max(200).optional().nullable(),
    is_valid: z.boolean().optional().default(true),
    is_synced: z.boolean().optional(),
});

export const syncBitesSchema = z.object({
    body: z.object({
        bites: z.array(biteSchema).min(1, "bites array is required and must not be empty").max(500, "Cannot sync more than 500 bites at once"),
    }),
    params: z.object({
        uuid: z.string().uuid("Invalid UUID format for meal"),
    }),
});

export const getBitesSchema = z.object({
    params: z.object({
        uuid: z.string().uuid("Invalid UUID format for meal"),
    }),
});
