import { Button } from "@/components/ui/button";

export function ExportButton() {
  // Plain <a>: the browser handles the download from /api/export
  return (
    <Button asChild variant="outline">
      <a href="/api/export" download>Export CSV</a>
    </Button>
  );
}
