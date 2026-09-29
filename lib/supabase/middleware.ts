// Refreshes the session cookie on each request and guards routes.
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll(list) {
          list.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          list.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        },
      },
    }
  );

  // getUser() re-validates the token with Supabase (unlike getSession()).
  const { data: { user } } = await supabase.auth.getUser();
  const isAdmin = user?.app_metadata?.role === "admin";
  const onLogin = request.nextUrl.pathname.startsWith("/login");

  if (!isAdmin && !onLogin) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  if (isAdmin && onLogin) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }
  return response;
}
