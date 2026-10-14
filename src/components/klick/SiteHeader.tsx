import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { Menu } from "lucide-react";

import { useCart } from "@/lib/cart";
import { useRole, useSession } from "@/lib/session";
import { KlickLogo } from "./KlickLogo";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";

type City = { id: string; name: string; slug: string };

const navLinkClass =
  "rounded-full px-3 py-1.5 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground";

export function SiteHeader({
  cities,
  activeCity,
  onCityChange,
}: {
  cities: City[];
  activeCity: string;
  onCityChange: (slug: string) => void;
}) {
  const { itemsCount } = useCart();
  const { user } = useSession();
  const { isPartner } = useRole();
  const [open, setOpen] = useState(false);

  const cityPicker = (
    <div className="flex rounded-full bg-surface-warm p-1">
      {cities.map((city) => (
        <button
          key={city.id}
          type="button"
          onClick={() => onCityChange(city.slug)}
          aria-pressed={activeCity === city.slug}
          className={`rounded-full px-3 py-1.5 text-sm font-medium transition-colors ${
            activeCity === city.slug
              ? "bg-primary text-primary-foreground"
              : "text-muted-foreground hover:text-foreground"
          }`}
        >
          {city.name}
        </button>
      ))}
    </div>
  );

  return (
    <header className="sticky top-0 z-30 border-b border-border bg-background/85 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-3 px-4">
        <KlickLogo compact />

        <div className="flex items-center gap-2">
          <span className="hidden text-sm text-muted-foreground lg:inline">Livraison à</span>
          {cities.length > 1 ? <div className="hidden sm:block">{cityPicker}</div> : cities[0] ? <span className="hidden text-sm font-semibold sm:inline">{cities[0].name}</span> : null}

          <Link to="/suivi" search={{ commande: "", tel: "" }} className={`hidden md:inline-block ${navLinkClass}`}>
            Suivi
          </Link>
          {isPartner && (
            <Link to="/operations" className={`hidden md:inline-block ${navLinkClass}`}>
              Espace pro
            </Link>
          )}
          <Link to={user ? "/mon-compte" : "/auth"} className={`hidden md:inline-block ${navLinkClass}`}>
            {user ? "Mon compte" : "Connexion"}
          </Link>

          <Link
            to="/panier"
            className="relative rounded-full bg-primary px-4 py-1.5 text-sm font-semibold text-primary-foreground"
          >
            Panier
            {itemsCount > 0 && (
              <span className="ml-2 rounded-full bg-primary-foreground/20 px-2 py-0.5 text-xs">{itemsCount}</span>
            )}
          </Link>

          <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger
              aria-label="Ouvrir le menu"
              className="rounded-full border border-border p-2 text-foreground lg:hidden"
            >
              <Menu className="h-5 w-5" />
            </SheetTrigger>
            <SheetContent side="right" className="w-[86vw] max-w-xs">
              <SheetHeader>
                <SheetTitle>Menu KLICK</SheetTitle>
              </SheetHeader>
              <div className="grid gap-4 px-4 pb-6 pt-2">
                <div className={cities.length > 1 ? "sm:hidden" : "hidden"}>
                  <p className="mb-2 text-sm text-muted-foreground">Livraison à</p>
                  {cityPicker}
                </div>
                <nav className="grid gap-1 text-base font-medium">
                  <Link to="/" onClick={() => setOpen(false)} className="rounded-md px-3 py-2 hover:bg-surface-warm">
                    Accueil
                  </Link>
                  <Link
                    to="/suivi"
                    search={{ commande: "", tel: "" }}
                    onClick={() => setOpen(false)}
                    className="rounded-md px-3 py-2 hover:bg-surface-warm"
                  >
                    Suivre une commande
                  </Link>
                  {isPartner && (
                    <Link
                      to="/operations"
                      onClick={() => setOpen(false)}
                      className="rounded-md px-3 py-2 hover:bg-surface-warm"
                    >
                      Espace pro
                    </Link>
                  )}
                  <Link
                    to={user ? "/mon-compte" : "/auth"}
                    onClick={() => setOpen(false)}
                    className="rounded-md px-3 py-2 hover:bg-surface-warm"
                  >
                    {user ? "Mon compte" : "Connexion"}
                  </Link>
                  <Link
                    to="/panier"
                    onClick={() => setOpen(false)}
                    className="rounded-md px-3 py-2 hover:bg-surface-warm"
                  >
                    Panier {itemsCount > 0 ? `(${itemsCount})` : ""}
                  </Link>
                </nav>
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  );
}
