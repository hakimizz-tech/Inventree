import { signOut } from "@/app/login/actions";
import { Button } from "@/components/ui/button";

export function LogoutButton() {
  return (
    <form action={signOut}>
      <Button variant="outline" type="submit">Sign out</Button>
    </form>
  );
}
