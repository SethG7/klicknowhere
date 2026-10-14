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
};

export function RestaurantCard({ restaurant }: { restaurant: RestaurantCardData }) {
  return (
    <Link
      to="/restaurant/$slug"
      params={{ slug: restaurant.slug }}
      className="group flex flex-col overflow-hidden rounded-2xl border border-border bg-card transition-shadow hover:shadow-lg"
    >
      <div className="relative flex h-36 items-center justify-center bg-surface-warm">
        <span className="font-display text-3xl font-extrabold text-primary/25">
          {restaurant.name.slice(0, 2).toUpperCase()}
        </span>
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
        <div className="mt-3 flex items-center gap-3 text-xs text-muted-foreground">
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
      </div>
    </Link>
  );
}
