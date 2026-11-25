import "server-only";
import { isSupabaseConfigured } from "./supabase/env";
import { createClient } from "./supabase/server";

export type JobType =
  | "full_time" | "part_time" | "contract" | "temporary" | "learnership" | "internship" | "graduate_programme";

export type JobSummary = {
  id: string;
  title: string;
  employer: string;
  town: string;
  category: string | null;
  jobType: JobType;
  salaryMin: number | null;
  salaryMax: number | null;
  closingDate: string; // YYYY-MM-DD
  featured: boolean;
};

export const jobTypeLabels: Record<JobType, string> = {
  full_time: "Full-time",
  part_time: "Part-time",
  contract: "Contract",
  temporary: "Temporary",
  learnership: "Learnership",
  internship: "Internship",
  graduate_programme: "Graduate programme",
};

function daysFromToday(days: number) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

// Shown until Supabase is connected. Clearly labelled as samples in the UI.
const sampleJobs: JobSummary[] = [
  { id: "sample-1", title: "General Worker (Dairy)", employer: "Sample Dairy Co.", town: "Standerton",
    category: "Agriculture and Farming", jobType: "full_time", salaryMin: 4800, salaryMax: 5500,
    closingDate: daysFromToday(3), featured: true },
  { id: "sample-2", title: "Cashier", employer: "Sample Retail", town: "Standerton",
    category: "Retail and Sales", jobType: "part_time", salaryMin: 3200, salaryMax: null,
    closingDate: daysFromToday(9), featured: false },
  { id: "sample-3", title: "Electrical Learnership (NQF 2)", employer: "Sample Training Centre", town: "Sakhile",
    category: "Learnerships and Internships", jobType: "learnership", salaryMin: 2500, salaryMax: 2500,
    closingDate: daysFromToday(14), featured: true },
  { id: "sample-4", title: "Admin Intern", employer: "Sample Municipality Office", town: "Standerton",
    category: "Admin and Office", jobType: "internship", salaryMin: null, salaryMax: null,
    closingDate: daysFromToday(21), featured: false },
  { id: "sample-5", title: "Code 10 Truck Driver", employer: "Sample Logistics", town: "Morgenzon",
    category: "Transport and Logistics", jobType: "contract", salaryMin: 9000, salaryMax: 11000,
    closingDate: daysFromToday(6), featured: false },
];

export type JobFilters = { q?: string; town?: string };

export async function getOpenJobs(filters: JobFilters = {}): Promise<{ jobs: JobSummary[]; sample: boolean }> {
  const q = filters.q?.trim().toLowerCase();
  const town = filters.town?.trim().toLowerCase();

  if (!isSupabaseConfigured) {
    const jobs = sampleJobs.filter(
      (j) =>
        (!q || `${j.title} ${j.employer} ${j.category ?? ""}`.toLowerCase().includes(q)) &&
        (!town || j.town.toLowerCase() === town),
    );
    return { jobs, sample: true };
  }

  const supabase = await createClient();
  let query = supabase
    .from("jobs")
    .select(
      "id, title, job_type, salary_min, salary_max, closing_date, listing_tier, employers(name), towns!inner(name, slug), job_categories(name)",
    )
    .eq("status", "published")
    .gte("closing_date", new Date().toISOString().slice(0, 10))
    .order("listing_tier", { ascending: false })
    .order("closing_date", { ascending: true })
    .limit(50);

  if (q) query = query.ilike("title", `%${q.replace(/[%_,()]/g, " ")}%`);
  if (town) query = query.eq("towns.slug", town);

  const { data, error } = await query;
  if (error) throw new Error(`Could not load jobs: ${error.message}`);

  type Row = {
    id: string; title: string; job_type: JobType; salary_min: number | null; salary_max: number | null;
    closing_date: string; listing_tier: "starter" | "featured";
    employers: { name: string } | null; towns: { name: string } | null; job_categories: { name: string } | null;
  };

  const jobs = ((data ?? []) as unknown as Row[]).map((r) => ({
    id: r.id,
    title: r.title,
    employer: r.employers?.name ?? "",
    town: r.towns?.name ?? "",
    category: r.job_categories?.name ?? null,
    jobType: r.job_type,
    salaryMin: r.salary_min,
    salaryMax: r.salary_max,
    closingDate: r.closing_date,
    featured: r.listing_tier === "featured",
  }));
  return { jobs, sample: false };
}

export function formatSalary(min: number | null, max: number | null) {
  const r = (n: number) => `R${n.toLocaleString("en-ZA")}`;
  if (min && max && min !== max) return `${r(min)} – ${r(max)} pm`;
  if (min) return `${r(min)} pm`;
  if (max) return `Up to ${r(max)} pm`;
  return "Salary not stated";
}

export function daysLeft(closingDate: string) {
  const today = new Date(new Date().toISOString().slice(0, 10));
  const close = new Date(closingDate);
  return Math.round((close.getTime() - today.getTime()) / 86_400_000);
}
