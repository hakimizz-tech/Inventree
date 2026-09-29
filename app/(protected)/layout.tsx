import { redirect } from "next/navigation";
import { requireAdmin } from "@/lib/auth/require-admin";
import { LogoutButton } from "@/components/logout-button";
import { Toaster } from "@/components/ui/sonner";

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  try {
    await requireAdmin();
  } catch {
    redirect("/login");
  }
  return (
    <div className="mx-auto max-w-5xl p-6">
      <header className="mb-6 flex items-center justify-between">
        <h1 className="text-xl font-semibold">Inventory</h1>
        <LogoutButton />
      </header>
      {children}
      <Toaster />
    </div>
  );
}
