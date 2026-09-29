import { buttonVariants } from "@/components/ui/button";

export function ExportButton() {
  return (
    <a 
      href="/api/export" 
      download 
      className={buttonVariants({ variant: "outline" })}
    >
      Export CSV
    </a>
  );
}