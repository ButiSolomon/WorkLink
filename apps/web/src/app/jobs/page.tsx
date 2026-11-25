import type { Metadata } from "next";
import { Suspense } from "react";
import { JobCard } from "@/components/job-card";
import { SearchForm } from "@/components/search-form";
import { getOpenJobs } from "@/lib/jobs";

export const metadata: Metadata = { title: "Find jobs" };

type SearchParams = Promise<{ q?: string | string[]; town?: string | string[] }>;

function first(v: string | string[] | undefined) {
  return Array.isArray(v) ? v[0] : v;
}

async function JobResults({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const q = first(params.q) ?? "";
  const town = first(params.town) ?? "";
  const { jobs, sample } = await getOpenJobs({ q, town });

  return (
    <>
      <div className="-mt-8 mb-6">
        <SearchForm q={q} town={town} />
      </div>
      {sample && (
        <p className="mb-4 rounded-xl border border-amber-700/20 bg-amber-50 px-4 py-3 text-sm text-amber-700">
          These are sample jobs. Real vacancies appear once the database is connected.
        </p>
      )}
      <p className="mb-3 text-sm font-semibold text-muted">
        {jobs.length} open {jobs.length === 1 ? "job" : "jobs"}
      </p>
      {jobs.length === 0 ? (
        <p className="rounded-2xl border border-line bg-white p-6 text-muted">
          No open jobs match your search yet. Try another keyword or town.
        </p>
      ) : (
        <div className="grid gap-3">
          {jobs.map((job) => (
            <JobCard key={job.id} job={job} />
          ))}
        </div>
      )}
    </>
  );
}

export default function JobsPage({ searchParams }: { searchParams: SearchParams }) {
  return (
    <>
      <section className="bg-navy-900 pb-14 pt-8 text-white">
        <div className="mx-auto max-w-3xl px-4">
          <h1 className="font-display text-3xl font-extrabold">Find jobs</h1>
          <p className="mt-1 text-white/75">Jobs, learnerships and internships near you.</p>
        </div>
      </section>
      <div className="mx-auto max-w-3xl px-4">
        <Suspense fallback={<p className="py-10 text-center text-muted">Loading jobs…</p>}>
          <JobResults searchParams={searchParams} />
        </Suspense>
      </div>
    </>
  );
}
