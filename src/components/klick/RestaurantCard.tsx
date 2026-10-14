import { Link } from "@tanstack/react-router";
import { formatPrice } from "@/lib/klick";

export type RestaurantCardData = {
  id: string;
  name: string;
  slug: string;
  cuisine_summary: string | null;
  rating: number;
  reviews_count: number;
  eta_min_minutes: number;
  eta_max_minutes: number;
  is_open: boolean;
  delivery_zones: { name: string; delivery_fee: number } | null;
  currencySymbol: string;
  logo_url?: string | null;
  cover_url?: string | null;
};

export function RestaurantCard({ restaurant }: { restaurant: RestaurantCardData }) {
  return (
    <Link
      to="/restaurant/$slug"
      params={{ slug: restaurant.slug }}
      className="group flex flex-col overflow-hidden rounded-2xl border border-border bg-card transition-shadow hover:shadow-lg"
    >
      <div className="relative flex h-40 items-center justify-center overflow-hidden bg-surface-warm sm:h-44">
        {restaurant.cover_url || restaurant.logo_url ? (
          <img
            src={restaurant.cover_url || restaurant.logo_url || undefined}
            alt={`Visuel de ${restaurant.name}`}
            loading="lazy"
            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-[1.03]"
          />
        ) : (
          <span className="font-display text-3xl font-extrabold text-primary/25">
            {restaurant.name.slice(0, 2).toUpperCase()}
          </span>
        )}
        <span className="absolute left-3 top-3 rounded-full bg-card px-2.5 py-1 text-xs font-semibold text-foreground shadow-sm">
          ★ {Number(restaurant.rating).toFixed(1)}{" "}
          <span className="text-muted-foreground">({restaurant.reviews_count})</span>
        </span>
        {!restaurant.is_open && (
          <span className="absolute right-3 top-3 rounded-full bg-foreground/85 px-2.5 py-1 text-xs font-semibold text-background">
            Fermé
          </span>
        )}
      </div>

      <div className="flex flex-1 flex-col gap-1 p-4">
        <h3 className="font-display text-base font-semibold">{restaurant.name}</h3>
        <p className="text-sm text-muted-foreground">{restaurant.cuisine_summary}</p>
        <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
          <span>
            {restaurant.eta_min_minutes}–{restaurant.eta_max_minutes} min
          </span>
          {restaurant.delivery_zones && (
            <>
              <span aria-hidden>•</span>
              <span>
                {formatPrice(restaurant.delivery_zones.delivery_fee, restaurant.currencySymbol)} de
                livraison
              </span>
              <span aria-hidden>•</span>
              <span>{restaurant.delivery_zones.name}</span>
            </>
          )}
        </div>
        <div className="mt-4 flex items-center justify-between border-t border-border pt-3">
          <span className="text-sm font-bold text-primary">Voir le menu</span>
          <span aria-hidden="true" className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">→</span>
        </div>
      </div>
    </Link>
  );
}
