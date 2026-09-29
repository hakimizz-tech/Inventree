import { z } from "zod";

export const inventoryInputSchema = z.object({
  rawText: z
    .string()
    .trim()
    .min(10, "Paste the device report first.")
    .max(5000, "Text is too long (max 5,000 characters)."),
});

// Required labels after parsing
export const requiredParsedSchema = z.object({
  hostname: z.string().min(1, "Missing 'Device Hostname'"),
  serial_number: z.string().min(1, "Missing 'Serial Number (S/N)'"),
});
