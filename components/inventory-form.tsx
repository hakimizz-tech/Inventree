"use client";

import { useActionState, useEffect, useRef } from "react";
import { toast } from "sonner";
import { saveItem, type SaveState } from "@/app/(protected)/dashboard/actions";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";

export function InventoryForm() {
  const [state, action, pending] = useActionState<SaveState, FormData>(saveItem, {});
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (!state.message) return;
    if (state.ok) {
      toast.success(state.message);
      formRef.current?.reset(); // clear the textbox after a successful save
    } else {
      toast.error(state.message);
    }
  }, [state]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Record a device</CardTitle>
      </CardHeader>
      <CardContent>
        <form ref={formRef} action={action} className="space-y-4">
          <Textarea
            name="rawText"
            rows={12}
            maxLength={5000}
            className="font-mono text-sm"
            placeholder={"Device Hostname     : DESKTOP-XXXX\nSerial Number (S/N) : ..."}
            required
          />
          <Button type="submit" disabled={pending}>
            {pending ? "Saving…" : "Save device"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
