# Security and POPIA checklist

Lekwa WorkLink holds CVs, contact details, qualifications and work history. This checklist tracks what the code
already does and what still needs a decision or a document before launch.

| Requirement | Status |
| --- | --- |
| Free for job seekers (Employment Services Act s15) | Business rule; no payment features exist for job seekers. |
| Private Employment Agency registration (ESA s13) | **To do:** request written guidance from the Department of Employment and Labour before launch. |
| Privacy notice | Draft page at `/privacy`. **To do:** final text reviewed by a lawyer; appoint an Information Officer and register with the Information Regulator. |
| Consent and data-processing notices | `consent_records` stores every grant/withdrawal with policy version. Sign-up UI to capture it is next. |
| Secure authentication | Supabase Auth; sessions refreshed server-side. |
| Restricted employer access to CVs | Row-level security + private storage bucket; tested. |
| Access logs | `audit_logs` (CV access, status changes, job publishing, consent). |
| Data deletion | `data_deletion_requests` table; admin workflow is on the roadmap. |
| Backups | Supabase daily backups on paid plans. **To do:** move to Pro before launch. |
| Data breach response | **To do:** write a one-page procedure (who to notify, Information Regulator within a reasonable time). |
| Operator agreements | **To do:** accept Supabase, Vercel and Resend DPAs; note cross-border transfer (POPIA s72). |
| WhatsApp | Only with `whatsapp_notifications` consent; honour opt-outs; approved templates only. |

## Key handling

- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` is safe in the browser because RLS protects all data.
- The secret / service-role key bypasses RLS. It must only live in server environment variables and must
  never be prefixed with `NEXT_PUBLIC_`.
- Reminisce Tech must own the GitHub, Supabase, Vercel, domain and payment accounts.
