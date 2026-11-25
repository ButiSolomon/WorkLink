# WORKLINK demo (no backend)

`index.html` is a single-file, working demo of WORKLINK that needs no database or server.
Everything is stored in the browser's local storage on the device that opens it.

It covers the V1 flows end to end:

- **Job seeker:** search and filter jobs, job details, save jobs, apply, track status, withdraw,
  CV builder with three templates and live preview, profile, POPIA consent choices, deletion request.
- **Employer:** dashboard, applicants per job (only applicants to their own jobs), open CV,
  change application status, post a job (goes to review), close a job, company profile and plan.
- **Admin:** approve or reject jobs (unverified employers cannot go live), verify employers, overview.

Use the **View as** menu at the top to switch between job seeker, employer and admin.
"Reset demo data" in the footer restores the sample data.

## Hosting it

It is a plain HTML file, so it can be hosted anywhere static files are served
(Vercel, Netlify, GitHub Pages, any web host). The page loads Google Fonts and
falls back to system fonts offline.

The real app lives in `apps/web` with Supabase. This demo is for showing the product
and testing flows with people in Standerton before the backend is set up.
Not included in the demo: real sign-in, PDF download, emails/WhatsApp and payments.
