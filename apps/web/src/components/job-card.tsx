import { daysLeft, formatSalary, jobTypeLabels, type JobSummary } from "@/lib/jobs";

export function JobCard({ job }: { job: JobSummary }) {
  const left = daysLeft(job.closingDate);
  const urgent = left <= 5;
  return (
    <article className="rounded-2xl border border-line bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="font-display text-lg font-bold leading-snug text-navy-900">{job.title}</h3>
          <p className="mt-0.5 truncate text-sm text-muted">
            {job.employer} · {job.town}
          </p>
        </div>
        {job.featured && (
          <span className="shrink-0 rounded-full bg-teal-50 px-2.5 py-1 text-xs font-bold text-teal-700">
            Featured
          </span>
        )}
      </div>
      <div className="mt-3 flex flex-wrap gap-2 text-xs font-semibold">
        <span className="rounded-full bg-paper px-2.5 py-1 text-navy-800">{jobTypeLabels[job.jobType]}</span>
        <span className="rounded-full bg-paper px-2.5 py-1 text-navy-800">
          {formatSalary(job.salaryMin, job.salaryMax)}
        </span>
        <span
          className={`rounded-full px-2.5 py-1 ${urgent ? "bg-amber-50 text-amber-700" : "bg-paper text-navy-800"}`}
        >
          {left === 0 ? "Closes today" : `Closes in ${left} day${left === 1 ? "" : "s"}`}
        </span>
      </div>
    </article>
  );
}
