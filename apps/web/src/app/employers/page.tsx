import type { Metadata } from "next";

export const metadata: Metadata = { title: "For employers" };

const plans = [
  { name: "Starter ad", price: "R149", per: "per job", points: ["One job ad for 30 days", "Applicant list and CV downloads", "Update applicant status"] },
  { name: "Featured ad", price: "R249", per: "per job", highlight: true, points: ["Everything in Starter", "Top of search results", "Included in job alert emails"] },
  { name: "Business Pro", price: "R499", per: "per month", points: ["Unlimited job ads", "Team access for recruiters", "Verified employer badge"] },
];

export default function EmployersPage() {
  return (
    <>
      <section className="bg-navy-900 py-10 text-white">
        <div className="mx-auto max-w-5xl px-4">
          <h1 className="font-display text-3xl font-extrabold sm:text-4xl">Hire local talent in Lekwa</h1>
          <p className="mt-2 max-w-xl text-white/75">
            Post vacancies, learnerships and internships. Every employer is verified before ads go live.
          </p>
        </div>
      </section>
      <section className="mx-auto grid max-w-5xl gap-4 px-4 py-10 sm:grid-cols-3">
        {plans.map((p) => (
          <div
            key={p.name}
            className={`rounded-2xl border bg-white p-6 ${p.highlight ? "border-teal-700 ring-2 ring-teal-700" : "border-line"}`}
          >
            <h2 className="font-display text-lg font-bold text-navy-900">{p.name}</h2>
            <p className="mt-2">
              <span className="font-display text-3xl font-extrabold text-navy-900">{p.price}</span>{" "}
              <span className="text-muted">{p.per}</span>
            </p>
            <ul className="mt-4 space-y-2 text-sm text-ink">
              {p.points.map((pt) => (
                <li key={pt} className="flex gap-2">
                  <span aria-hidden="true" className="text-teal-700">✓</span>
                  {pt}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </section>
      <p className="mx-auto max-w-5xl px-4 text-sm text-muted">
        Employer sign-up and payments are coming soon. Prices include VAT where applicable.
      </p>
    </>
  );
}
