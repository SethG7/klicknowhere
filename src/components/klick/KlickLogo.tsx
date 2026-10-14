import { Link } from "@tanstack/react-router";

export function KlickLogo({ compact = false }: { compact?: boolean }) {
  return (
    <Link to="/" className="flex items-center gap-2.5" aria-label="KLICK — Accueil">
      <img src="/klick-logo.png" alt="" className="h-10 w-10 object-contain" />
      {!compact && <span className="font-display text-base font-extrabold text-foreground">KLICK</span>}
    </Link>
  );
}