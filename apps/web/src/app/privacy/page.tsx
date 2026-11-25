import type { Metadata } from "next";

export const metadata: Metadata = { title: "Privacy" };

// DRAFT placeholder. Replace with the final policy after legal review before launch.
export default function PrivacyPage() {
  return (
    <article className="mx-auto max-w-3xl px-4 py-10 leading-relaxed">
      <h1 className="font-display text-3xl font-extrabold text-navy-900">Privacy and your information</h1>
      <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
        Draft. This notice will be finalised before WORKLINK launches.
      </p>
      <div className="mt-6 space-y-4 text-ink">
        <p>
          WORKLINK, a Reminisce Tech product, processes your personal information under the Protection of
          Personal Information Act (POPIA) so that you can find work and apply for jobs.
        </p>
        <h2 className="font-display text-xl font-bold text-navy-900">What employers can see</h2>
        <p>
          Employers only see your profile and CV when you apply to one of their jobs. If you withdraw an
          application, that employer can no longer open your CV on WORKLINK.
        </p>
        <h2 className="font-display text-xl font-bold text-navy-900">Your choices</h2>
        <p>
          You choose whether to receive email job alerts and WhatsApp messages, and you can change your mind at
          any time. You can ask us to delete your account and information.
        </p>
        <h2 className="font-display text-xl font-bold text-navy-900">Free for job seekers</h2>
        <p>WORKLINK never charges job seekers for searching, building a CV, applying or getting an interview.</p>
      </div>
    </article>
  );
}
