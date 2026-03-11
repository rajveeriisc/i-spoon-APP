import { z } from 'zod';

const isoDateString = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Must be a valid YYYY-MM-DD date");

export const getDashboardSchema = z.object({
    query: z.object({
        days: z.string().optional().transform(val => {
            const n = val ? parseInt(val, 10) : 90;
            return Math.min(Math.max(n || 1, 1), 365); // clamp 1–365 days
        }),
    })
});

export const getAnalyticsByDateSchema = z.object({
    params: z.object({
        date: isoDateString,
    })
});

export const getSummarySchema = z.object({
    query: z.object({
        start_date: isoDateString,
        end_date: isoDateString,
    })
}).refine(data => {
    return new Date(data.query.start_date) <= new Date(data.query.end_date);
}, {
    message: "start_date must be before or equal to end_date",
    path: ["query", "start_date"]
});
