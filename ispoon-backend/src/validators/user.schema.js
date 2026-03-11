import { z } from 'zod';

export const updateProfileSchema = z.object({
    body: z.object({
        name: z.string().min(2, "Name must be at least 2 characters").max(100).optional().nullable(),
        phone: z.string().regex(/^\+?[\d\s-]{10,15}$/, "Invalid phone format").optional().nullable(),
        gender: z.enum(['male', 'female', 'other', 'prefer_not_to_say']).optional().nullable(),
        location: z.string().max(100).optional().nullable(),
        age: z.number().int().min(13, "Must be at least 13").max(120).optional().nullable(),
        notifications_enabled: z.boolean().optional().nullable(),
    })
});
