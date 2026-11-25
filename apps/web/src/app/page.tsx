import Link from "next/link";
import { SearchForm } from "@/components/search-form";

const categories = [
  "Agriculture", "Retail", "Learnerships", "Internships", "Transport", "Admin", "Security", "Construction",
];

const steps = [
  { title: "Create a free profile", body: "Sign up with your email or phone. No CV needed to start." },
  { title: "Build your CV", body: "Fill in simple steps and download a professional PDF CV for free." },
  { title: "Apply and track", body: "Apply in a few taps and see when an employer views or shortlists you." },
];

export default function HomePage() {
  return (
    <>
      <section className="bg-navy-900 text-white">
        <div className="mx-auto max-w-5xl px-4 pb-12 pt-10 sm:pb-16 sm:pt-16">
          <p className="text-sm font-semibold uppercase tracking-wider text-teal-400">Standerton · Lekwa · Mpumalanga</p>
          <h1 className="mt-3 max-w-2xl font-display text-4xl font-extrabold leading-tight sm:text-5xl">
            Local jobs, learnerships and a free CV, all from your phone.
          </h1>
          <p className="mt-4 max-w-xl text-lg text-white/80">
            WORKLINK is free for job seekers. Always. No fees to search, build a CV or apply.
          </p>
          <div className="mt-8 max-w-3xl">
            <SearchForm />
          </div>
          <div className="mt-6 flex flex-wrap gap-2">
            {categories.map((c) => (
              <Link
                key={c}
                href={`/jobs?q=${encodeURIComponent(c)}`}
                className="rounded-full border border-white/20 px-3 py-1.5 text-sm hover:bg-white/10"
              >
                {c}
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-4 py-12">
        <h2 className="font-display text-2xl font-bold text-navy-900">How WORKLINK works</h2>
        <ol className="mt-6 grid gap-4 sm:grid-cols-3">
          {steps.map((s, i) => (
            <li key={s.title} className="rounded-2xl border border-line bg-white p-5">
              <span className="flex h-9 w-9 items-center justify-center rounded-full bg-teal-50 font-display font-bold text-teal-700">
                {i + 1}
              </span>
              <h3 className="mt-3 font-display text-lg font-bold text-navy-900">{s.title}</h3>
              <p className="mt-1 text-muted">{s.body}</p>
            </li>
          ))}
        </ol>
      </section>

      <section className="mx-auto max-w-5xl px-4">
        <div className="flex flex-col gap-4 rounded-3xl bg-teal-700 p-6 text-white sm:flex-row sm:items-center sm:justify-between sm:p-8">
          <div>
            <h2 className="font-display text-2xl font-bold">Hiring in Lekwa?</h2>
            <p className="mt-1 text-white/85">Reach local candidates from R149 per job ad.</p>
          </div>
          <Link href="/employers" className="rounded-xl bg-white px-5 py-3 text-center font-bold text-teal-700">
            See employer plans
          </Link>
        </div>
      </section>
    </>
  );
}
