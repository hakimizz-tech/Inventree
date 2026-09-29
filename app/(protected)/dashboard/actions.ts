"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth/require-admin";
import { limiter } from "@/lib/ratelimit";
import { parseDeviceText } from "@/lib/parser/parse-device-text";
import { inventoryInputSchema, requiredParsedSchema } from "@/lib/validation/inventory";

export type SaveState = { ok?: boolean; message?: string; ts?: number };

export async function saveItem(_prev: SaveState, formData: FormData): Promise<SaveState> {
  try {
    const { supabase, user } = await requireAdmin();

    if (limiter) {
      const { success } = await limiter.limit(`save:${user.id}`);
      if (!success) return { message: "Slow down — too many saves." };
    }

    const input = inventoryInputSchema.safeParse({ rawText: formData.get("rawText") });
    if (!input.success) {
      console.error("Raw Text Validation Failed:", input.error.issues);
      return { message: input.error.issues[0].message };
    }

    const parsed = parseDeviceText(input.data.rawText);
    const required = requiredParsedSchema.safeParse(parsed);
    if (!required.success) {
      console.error("Parsed Fields Validation Failed:", required.error.issues);
      return { message: required.error.issues.map((i) => i.message).join(", ") };
    }

    const { error } = await supabase
      .from("inventory_items")
      .insert({ raw_text: input.data.rawText, ...parsed });

    if (error) {
      // This will print the exact database rejection reason to your terminal
      console.error("Supabase Insert Error:", error); 
      
      if (error.code === "23505") {
        return { message: "A device with this serial number already exists." };
      }
      return { message: "Could not save. Please try again." };
    }

    revalidatePath("/dashboard");
    return { ok: true, message: "Device saved.", ts: Date.now() };
  } catch (err) {
    console.error("Authorization/Catch Block Error:", err);
    return { message: "Unauthorized." };
  }
}

export async function deleteItem(id: string): Promise<void> {
  const { supabase } = await requireAdmin();
  await supabase.from("inventory_items").delete().eq("id", id);
  revalidatePath("/dashboard");
}