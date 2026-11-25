import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="mt-16 bg-navy-950 text-sm text-white/70">
      <div className="mx-auto grid max-w-5xl gap-6 px-4 py-10 sm:grid-cols-3">
        <div>
          <p className="font-display text-base font-bold text-white">Lekwa WorkLink</p>
          <p className="mt-1">Opportunities. Employment. Growth.</p>
          <p className="mt-3">A Reminisce Tech product, part of Reminisce Group.</p>
        </div>
        <div>
          <p className="font-semibold text-white">Always free for job seekers</p>
          <p className="mt-1">
            Lekwa WorkLink never charges job seekers to search, build a CV, apply or get an interview.
          </p>
        </div>
        <nav className="flex flex-col gap-2">
          <Link href="/jobs" className="hover:text-white">Find jobs</Link>
          <Link href="/employers" className="hover:text-white">Post a job</Link>
          <Link href="/privacy" className="hover:text-white">Privacy (POPIA)</Link>
        </nav>
      </div>
    </footer>
  );
}
