import Link from "next/link";
import { Logo } from "./logo";

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-20 border-b border-white/10 bg-navy-900 text-white">
      <div className="mx-auto flex h-16 max-w-5xl items-center justify-between gap-4 px-4">
        <Link href="/" aria-label="Lekwa WorkLink home">
          <Logo />
        </Link>
        <nav className="flex items-center gap-1 text-sm font-semibold">
          <Link href="/jobs" className="rounded-lg px-3 py-2 hover:bg-white/10">Jobs</Link>
          <Link href="/employers" className="rounded-lg px-3 py-2 hover:bg-white/10">Employers</Link>
        </nav>
      </div>
    </header>
  );
}
