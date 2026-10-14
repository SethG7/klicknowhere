import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { formatPrice } from "@/lib/klick";
import { getCommissionOverview, setCommissionRate, setRestaurantVisibility } from "@/lib/operations.functions";

export function CommissionsModule() {
  const fetchOverview = useServerFn(getCommissionOverview);
  const save = useServerFn(setCommissionRate);
  const setVisible = useServerFn(setRestaurantVisibility);
  const qc = useQueryClient();
  const { data, isLoading, error } = useQuery({ queryKey: ["commissions"], queryFn: () => fetchOverview() });
  const [draft, setDraft] = useState<Record<string, string>>({});
  if (isLoading) return <p className="mt-8 text-muted-foreground">Chargement…</p>;
  if (error) return <p className="mt-8 text-sm text-muted-foreground">Module réservé à la direction KLICK.</p>;
  const totalCommission = (data ?? []).reduce((s, r) => s + r.commission, 0);
  return (
    <section className="mt-8 grid gap-4">
      <div className="rounded-lg border border-border bg-card p-5">
        <p className="text-sm text-muted-foreground">Commissions KLICK encaissées (figées par commande)</p>
        <p className="mt-1 text-2xl font-bold">{formatPrice(totalCommission, "CDF")}</p>
        <p className="mt-2 text-xs text-muted-foreground">Modifier un taux ne s'applique qu'aux nouvelles commandes ; l'historique reste inchangé.</p>
      </div>
      {(data ?? []).map((r) => {
        const value = draft[r.id] ?? String(Math.round(Number(r.commission_rate) * 1000) / 10);
        return (
          <article key={r.id} className="flex flex-wrap items-center justify-between gap-4 rounded-lg border border-border bg-card p-5">
            <div className="min-w-0">
              <p className="font-bold">{r.name} {r.status !== "approved" && <span className="ml-2 rounded-full bg-muted px-2 py-0.5 text-xs font-medium text-muted-foreground">Masqué</span>}</p>
              <p className="text-sm text-muted-foreground">{r.orders} commande(s) · KLICK {formatPrice(r.commission, "CDF")} · Restaurant {formatPrice(r.payout, "CDF")}</p>
            </div>
            <div className="flex items-center gap-2">
              <Input aria-label={`Taux ${r.name}`} className="w-20" type="number" min={0} max={50} step={0.5} value={value} onChange={(e) => setDraft({ ...draft, [r.id]: e.target.value })} />
              <span className="text-sm">%</span>
              <Button size="sm" onClick={async () => {
                const n = Number(value);
                if (!Number.isFinite(n) || n < 0 || n > 50) { toast.error("Taux entre 0 et 50 %."); return; }
                try { await save({ data: { restaurantId: r.id, ratePercent: n } }); toast.success("Taux mis à jour"); qc.invalidateQueries({ queryKey: ["commissions"] }); } catch (e) { toast.error((e as Error).message); }
              }}>Enregistrer</Button>
              <Button size="sm" variant="outline" onClick={async () => {
                try { await setVisible({ data: { restaurantId: r.id, visible: r.status !== "approved" } }); toast.success(r.status === "approved" ? "Restaurant masqué du site" : "Restaurant visible sur le site"); qc.invalidateQueries({ queryKey: ["commissions"] }); } catch (e) { toast.error((e as Error).message); }
              }}>{r.status === "approved" ? "Masquer" : "Afficher"}</Button>
            </div>
          </article>
        );
      })}
    </section>
  );
}
