import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { Check, Clock3, MapPin, Pencil, Plus, Power, Store, WalletCards, X } from "lucide-react";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { formatPrice } from "@/lib/klick";
import {
  addRestaurantManager,
  createMenuCategory,
  getRestaurantTeam,
  removeRestaurantManager,
  getOperationsDashboard,
  saveProduct,
  toggleProduct,
  toggleRestaurant,
  updateRestaurantOrderStatus,
} from "@/lib/operations.functions";

type Dash = Awaited<ReturnType<typeof getOperationsDashboard>>;
type Data = Extract<Dash, { kind: "restaurant" }>;
type Product = Data["products"][number];

const statusLabel: Record<string, string> = {
  pending: "Nouvelle", confirmed: "Acceptée", preparing: "En préparation", ready: "Prête",
  driver_assigned: "Livreur assigné", picked_up: "Récupérée", on_the_way: "En route",
  delivered: "Livrée", cancelled: "Annulée",
};

function Metric({ icon: Icon, label, value }: { icon: typeof Clock3; label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-border bg-card p-4">
      <Icon className="h-5 w-5 text-primary" />
      <p className="mt-3 text-xl font-extrabold sm:text-2xl">{value}</p>
      <p className="mt-1 text-xs text-muted-foreground">{label}</p>
    </div>
  );
}

export function RestaurantSpace({ data }: { data: Data }) {
  const queryClient = useQueryClient();
  const refresh = () => queryClient.invalidateQueries({ queryKey: ["operations"] });
  const [tab, setTab] = useState<"commandes" | "menu" | "chiffres" | "equipe">("commandes");
  const restaurant = data.restaurants[0];
  const currency = data.orders[0]?.currency_code ?? "CDF";
  const switchRestaurant = useServerFn(toggleRestaurant);

  if (!restaurant) {
    return (
      <p className="rounded-2xl border border-dashed border-border p-10 text-center text-muted-foreground">
        Aucun restaurant n'est encore rattaché à votre compte. Contactez l'équipe KLICK.
      </p>
    );
  }

  const active = data.orders.filter((o) => !["delivered", "cancelled"].includes(o.status));
  const tabs = [
    ["commandes", `Commandes${active.length ? ` (${active.length})` : ""}`],
    ["menu", "Menu"],
    ["chiffres", data.isOwner ? "Chiffres & commissions" : "Chiffre du jour"],
    ...(data.isOwner ? ([["equipe", "Mon équipe"]] as const) : []),
  ] as const;

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm font-semibold text-primary">
            Espace restaurant · {data.isOwner ? "Propriétaire" : "Manager"}
          </p>
          <h1 className="mt-1 text-2xl font-extrabold sm:text-3xl">{restaurant.name}</h1>
        </div>
        <Button
          variant={restaurant.is_open ? "default" : "outline"}
          className="rounded-full"
          onClick={async () => {
            await switchRestaurant({ data: { restaurantId: restaurant.id, isOpen: !restaurant.is_open } });
            refresh();
          }}
        >
          <Power /> {restaurant.is_open ? "Ouvert — fermer" : "Fermé — ouvrir"}
        </Button>
      </div>

      <nav className="mt-6 flex gap-2 overflow-x-auto" aria-label="Modules restaurant">
        {tabs.map(([key, label]) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={`whitespace-nowrap rounded-full px-4 py-2 text-sm font-semibold ${
              tab === key ? "bg-primary text-primary-foreground" : "border border-border bg-card text-muted-foreground"
            }`}
          >
            {label}
          </button>
        ))}
      </nav>

      <div className="mt-6">
        {tab === "commandes" && <OrdersTab orders={active} onDone={refresh} />}
        {tab === "menu" && <MenuTab data={data} restaurantId={restaurant.id} currency={currency} onDone={refresh} />}
        {tab === "chiffres" && <FiguresTab data={data} currency={currency} />}
        {tab === "equipe" && data.isOwner && <TeamTab restaurantId={restaurant.id} />}
      </div>
    </>
  );
}

function OrdersTab({ orders, onDone }: { orders: Data["orders"]; onDone: () => void }) {
  const changeStatus = useServerFn(updateRestaurantOrderStatus);
  const mutation = useMutation({
    mutationFn: (input: { orderId: string; status: "confirmed" | "preparing" | "ready" | "cancelled" }) =>
      changeStatus({ data: input }),
    onSuccess: onDone,
    onError: (e) => toast.error(e instanceof Error ? e.message : "Action impossible."),
  });
  if (orders.length === 0)
    return <p className="rounded-2xl border border-dashed border-border p-10 text-center text-muted-foreground">Aucune commande en cours.</p>;
  return (
    <div className="grid gap-3">
      {orders.map((order) => {
        const next = order.status === "pending" ? "confirmed" : order.status === "confirmed" ? "preparing" : order.status === "preparing" ? "ready" : null;
        return (
          <article key={order.id} className="grid gap-4 rounded-2xl border border-border bg-card p-5 md:grid-cols-[1fr_auto] md:items-center">
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <strong>{order.order_number}</strong>
                <Badge variant="secondary">{statusLabel[order.status]}</Badge>
                <span className="text-xs text-muted-foreground">
                  {new Date(order.created_at).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}
                </span>
              </div>
              <p className="mt-2 text-sm">{order.order_items.map((i) => `${i.quantity}× ${i.product_name}`).join(" · ")}</p>
              {order.customer_notes && <p className="mt-1 text-sm italic text-muted-foreground">« {order.customer_notes} »</p>}
              <p className="mt-2 text-sm text-muted-foreground">
                <MapPin className="mr-1 inline h-4 w-4" />
                {order.delivery_quartier} · {formatPrice(Number(order.total), order.currency_code)} ·{" "}
                {order.payment_method === "cash" ? "Espèces" : "Mobile money"}
              </p>
            </div>
            {next && (
              <div className="flex gap-2">
                {order.status === "pending" && (
                  <Button variant="outline" size="sm" disabled={mutation.isPending} onClick={() => mutation.mutate({ orderId: order.id, status: "cancelled" })}>
                    <X /> Refuser
                  </Button>
                )}
                <Button size="sm" disabled={mutation.isPending} onClick={() => mutation.mutate({ orderId: order.id, status: next })}>
                  <Check /> {next === "confirmed" ? "Accepter" : next === "preparing" ? "Préparer" : "Marquer prête"}
                </Button>
              </div>
            )}
          </article>
        );
      })}
    </div>
  );
}

function MenuTab({ data, restaurantId, currency, onDone }: { data: Data; restaurantId: string; currency: string; onDone: () => void }) {
  const switchProduct = useServerFn(toggleProduct);
  const save = useServerFn(saveProduct);
  const addCategory = useServerFn(createMenuCategory);
  const [editing, setEditing] = useState<Product | "new" | null>(null);
  const [newCat, setNewCat] = useState("");
  const categories = data.categories.filter((c) => c.restaurant_id === restaurantId);
  const products = data.products.filter((p) => p.restaurant_id === restaurantId);
  const groups = [
    ...categories.map((c) => ({ id: c.id, name: c.name, items: products.filter((p) => p.category_id === c.id) })),
    { id: "none", name: "Sans catégorie", items: products.filter((p) => !p.category_id || !categories.some((c) => c.id === p.category_id)) },
  ].filter((g) => g.items.length > 0);

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    try {
      await save({
        data: {
          id: editing && editing !== "new" ? editing.id : undefined,
          restaurantId,
          name: String(f.get("name") ?? ""),
          description: String(f.get("description") ?? ""),
          price: Number(f.get("price")),
          categoryId: (f.get("categoryId") as string) || null,
        },
      });
      toast.success("Plat enregistré.");
      setEditing(null);
      onDone();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Vérifiez le nom et le prix.");
    }
  }

  const current = editing && editing !== "new" ? editing : null;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-2">
        <Button size="sm" className="rounded-full" onClick={() => setEditing("new")}><Plus /> Ajouter un plat</Button>
        <form
          className="flex gap-2"
          onSubmit={async (e) => {
            e.preventDefault();
            try {
              await addCategory({ data: { restaurantId, name: newCat } });
              setNewCat("");
              onDone();
            } catch {
              toast.error("Nom de catégorie invalide.");
            }
          }}
        >
          <input value={newCat} onChange={(e) => setNewCat(e.target.value)} placeholder="Nouvelle catégorie" className="w-40 rounded-full border border-border bg-background px-3 py-1.5 text-sm" />
          <Button size="sm" variant="outline" className="rounded-full" disabled={newCat.trim().length < 2}>Créer</Button>
        </form>
      </div>

      {editing && (
        <form key={current?.id ?? "new"} onSubmit={submit} className="grid gap-3 rounded-2xl border border-primary/40 bg-card p-5 sm:grid-cols-2">
          <p className="font-bold sm:col-span-2">{current ? "Modifier le plat" : "Nouveau plat"}</p>
          <input name="name" required defaultValue={current?.name} placeholder="Nom du plat" className="rounded-xl border border-border bg-background px-4 py-2.5 text-sm" />
          <input name="price" required type="number" min={1} step="any" defaultValue={current ? Number(current.price) : undefined} placeholder={`Prix (${currency})`} className="rounded-xl border border-border bg-background px-4 py-2.5 text-sm" />
          <select name="categoryId" defaultValue={current?.category_id ?? ""} className="rounded-xl border border-border bg-background px-4 py-2.5 text-sm">
            <option value="">Sans catégorie</option>
            {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          <input name="description" defaultValue={current?.description ?? ""} placeholder="Description (facultatif)" className="rounded-xl border border-border bg-background px-4 py-2.5 text-sm" />
          <div className="flex gap-2 sm:col-span-2">
            <Button type="submit" className="rounded-full">Enregistrer</Button>
            <Button type="button" variant="ghost" onClick={() => setEditing(null)}>Annuler</Button>
          </div>
          <p className="text-xs text-muted-foreground sm:col-span-2">Un changement de prix ne modifie jamais les commandes déjà passées.</p>
        </form>
      )}

      {groups.length === 0 ? (
        <p className="rounded-2xl border border-dashed border-border p-10 text-center text-muted-foreground">Aucun plat pour l'instant.</p>
      ) : (
        groups.map((g) => (
          <section key={g.id}>
            <h3 className="text-sm font-bold uppercase text-muted-foreground">{g.name}</h3>
            <div className="mt-2 divide-y divide-border rounded-2xl border border-border bg-card">
              {g.items.map((p) => (
                <div key={p.id} className="flex items-center justify-between gap-3 px-4 py-3">
                  <div className="min-w-0">
                    <p className="truncate font-medium">{p.name}</p>
                    <p className="text-sm text-muted-foreground">{formatPrice(Number(p.price), currency)}</p>
                  </div>
                  <div className="flex shrink-0 gap-2">
                    <Button size="icon" variant="ghost" aria-label={`Modifier ${p.name}`} onClick={() => setEditing(p)}><Pencil /></Button>
                    <Button
                      size="sm"
                      variant={p.is_available ? "outline" : "secondary"}
                      onClick={async () => {
                        await switchProduct({ data: { productId: p.id, isAvailable: !p.is_available } });
                        onDone();
                      }}
                    >
                      {p.is_available ? "Disponible" : "Indisponible"}
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </section>
        ))
      )}
    </div>
  );
}

function FiguresTab({ data, currency }: { data: Data; currency: string }) {
  const today = new Date().toDateString();
  const delivered = data.orders.filter((o) => o.status === "delivered");
  const todays = delivered.filter((o) => new Date(o.created_at).toDateString() === today);
  const sum = (list: typeof delivered, key: "total" | "commission_amount" | "restaurant_amount") =>
    list.reduce((s, o) => s + Number(o[key] ?? 0), 0);
  const avail = data.products.filter((p) => p.is_available).length;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Metric icon={WalletCards} label="Ventes livrées aujourd'hui" value={formatPrice(sum(todays, "total"), currency)} />
        <Metric icon={Clock3} label="Commandes livrées aujourd'hui" value={String(todays.length)} />
        <Metric icon={Store} label="Plats disponibles" value={`${avail}/${data.products.length}`} />
        <Metric icon={WalletCards} label="Ventes livrées (30 jours)" value={formatPrice(sum(delivered, "total"), currency)} />
      </div>
      {data.isOwner ? (
        <section className="rounded-2xl border border-border bg-card p-5">
          <h3 className="font-bold">Commissions KLICK (30 jours)</h3>
          <p className="mt-1 text-xs text-muted-foreground">Le taux est figé au moment de chaque commande.</p>
          <div className="mt-4 grid grid-cols-2 gap-4 text-sm">
            <div><p className="text-muted-foreground">Commission KLICK</p><p className="text-lg font-bold">{formatPrice(sum(delivered, "commission_amount"), currency)}</p></div>
            <div><p className="text-muted-foreground">Votre part</p><p className="text-lg font-bold text-success">{formatPrice(sum(delivered, "restaurant_amount"), currency)}</p></div>
          </div>
          <ul className="mt-4 divide-y divide-border text-sm">
            {delivered.slice(0, 15).map((o) => (
              <li key={o.id} className="flex justify-between gap-2 py-2">
                <span>{o.order_number} · {new Date(o.created_at).toLocaleDateString("fr-FR")}</span>
                <span className="text-muted-foreground">{formatPrice(Number(o.total), currency)} · {Number(o.commission_rate ?? 0)}%</span>
              </li>
            ))}
          </ul>
        </section>
      ) : (
        <p className="text-xs text-muted-foreground">Les commissions sont visibles uniquement par le propriétaire du restaurant.</p>
      )}
    </div>
  );
}

function TeamTab({ restaurantId }: { restaurantId: string }) {
  const fetchTeam = useServerFn(getRestaurantTeam);
  const add = useServerFn(addRestaurantManager);
  const remove = useServerFn(removeRestaurantManager);
  const queryClient = useQueryClient();
  const [email, setEmail] = useState("");
  const { data: team } = useQuery({ queryKey: ["restaurant-team", restaurantId], queryFn: () => fetchTeam({ data: { restaurantId } }) });
  const reload = () => queryClient.invalidateQueries({ queryKey: ["restaurant-team", restaurantId] });

  return (
    <div className="space-y-5">
      <form
        className="rounded-2xl border border-border bg-card p-5"
        onSubmit={async (e) => {
          e.preventDefault();
          try {
            await add({ data: { restaurantId, email } });
            toast.success("Manager ajouté.");
            setEmail("");
            reload();
          } catch (err) {
            toast.error(err instanceof Error ? err.message : "Ajout impossible.");
          }
        }}
      >
        <p className="font-bold">Ajouter un manager</p>
        <p className="mt-1 text-xs text-muted-foreground">
          La personne doit déjà avoir un compte KLICK. Un manager gère les commandes et le menu, mais ne voit pas les commissions.
        </p>
        <div className="mt-3 flex flex-col gap-2 sm:flex-row">
          <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email du manager" className="flex-1 rounded-xl border border-border bg-background px-4 py-2.5 text-sm" />
          <Button type="submit" className="rounded-full">Ajouter</Button>
        </div>
      </form>
      <ul className="divide-y divide-border rounded-2xl border border-border bg-card">
        {(team ?? []).map((m) => (
          <li key={m.user_id} className="flex items-center justify-between gap-3 px-4 py-3">
            <div className="min-w-0">
              <p className="truncate font-medium">{m.profiles?.full_name ?? m.profiles?.email}</p>
              <p className="truncate text-xs text-muted-foreground">{m.profiles?.email} · {m.member_role === "owner" ? "Propriétaire" : "Manager"}</p>
            </div>
            {m.member_role === "manager" && (
              <Button size="sm" variant="outline" onClick={async () => { await remove({ data: { restaurantId, userId: m.user_id } }); reload(); }}>
                Retirer
              </Button>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
