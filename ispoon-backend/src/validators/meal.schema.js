import { z } from 'zod';

export const createMealSchema = z.object({
    body: z.object({
        uuid: z.string().uuid("Invalid UUID format for meal").optional(),
        device_id: z.string().optional().nullable(),
        started_at: z.string().datetime("Invalid ISO datetime for started_at"),
        ended_at: z.string().datetime("Invalid ISO datetime for ended_at").optional().nullable(),
        meal_type: z.enum(['Breakfast', 'Lunch', 'Dinner', 'Snack']),
        total_bites: z.number().int().min(0).max(10000).optional(),
        avg_pace_bpm: z.number().min(0).max(500).optional().nullable(),
        tremor_index: z.number().int().min(0).max(3).optional(),
        duration_minutes: z.number().min(0).max(1440).optional().nullable(), // max 24h
        avg_food_temp_c: z.number().min(-10).max(200).optional().nullable(),
    }),
}).refine(data => {
    if (data.body.ended_at && data.body.started_at) {
        return new Date(data.body.ended_at) >= new Date(data.body.started_at);
    }
    return true;
}, { message: "ended_at must be after or equal to started_at", path: ["body", "ended_at"] });

export const updateMealSchema = z.object({
    body: z.object({
        ended_at: z.string().datetime("Invalid ISO datetime for ended_at").optional().nullable(),
        meal_type: z.enum(['Breakfast', 'Lunch', 'Dinner', 'Snack']).optional(),
        total_bites: z.number().int().min(0).max(10000).optional(),
        avg_pace_bpm: z.number().min(0).max(500).optional().nullable(),
        tremor_index: z.number().int().min(0).max(3).optional(),
        duration_minutes: z.number().min(0).max(1440).optional().nullable(),
        avg_food_temp_c: z.number().min(-10).max(200).optional().nullable(),
    }),
    params: z.object({
        id: z.string().regex(/^\d+$/, "ID must be a number"),
    }),
});

export const updateMealTemperatureSchema = z.object({
    body: z.object({
        avg_food_temp_c: z.number().min(-10).max(200),
        max_food_temp_c: z.number().min(-10).max(200).optional().nullable(),
        min_food_temp_c: z.number().min(-10).max(200).optional().nullable(),
    }),
    params: z.object({
        id: z.string().regex(/^\d+$/, "ID must be a number"),
    }),
});
