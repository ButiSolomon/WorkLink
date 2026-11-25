const towns = [
  { slug: "", name: "All towns" },
  { slug: "standerton", name: "Standerton" },
  { slug: "sakhile", name: "Sakhile" },
  { slug: "morgenzon", name: "Morgenzon" },
  { slug: "thuthukani", name: "Thuthukani" },
];

export function SearchForm({ q = "", town = "" }: { q?: string; town?: string }) {
  return (
    <form action="/jobs" className="grid gap-2 rounded-2xl bg-white p-2 shadow-lg sm:grid-cols-[1fr_auto_auto]">
      <label className="sr-only" htmlFor="q">Job title or keyword</label>
      <input
        id="q"
        name="q"
        defaultValue={q}
        placeholder="Job title or keyword, e.g. cashier"
        className="h-12 rounded-xl border border-line px-4 text-base text-ink outline-none focus:border-teal-600"
      />
      <label className="sr-only" htmlFor="town">Town</label>
      <select
        id="town"
        name="town"
        defaultValue={town}
        className="h-12 rounded-xl border border-line bg-white px-3 text-base text-ink"
      >
        {towns.map((t) => (
          <option key={t.slug} value={t.slug}>{t.name}</option>
        ))}
      </select>
      <button type="submit" className="h-12 rounded-xl bg-teal-700 px-6 font-bold text-white hover:bg-teal-600">
        Search jobs
      </button>
    </form>
  );
}
