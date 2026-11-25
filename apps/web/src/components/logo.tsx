export function Logo({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-2 ${className}`}>
      <svg viewBox="0 0 32 32" aria-hidden="true" className="h-8 w-8">
        <rect width="32" height="32" rx="7" fill="#0b1f3a" />
        <path d="M6.5 10l4.6 12L16 13.5 20.9 22l4.6-12" fill="none" stroke="#2bb5ae" strokeWidth="3"
          strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <span className="font-display text-xl font-extrabold tracking-tight">WORKLINK</span>
    </span>
  );
}
