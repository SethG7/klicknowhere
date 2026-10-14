-- KLICK LOT 17: manual Mobile Money proof submission and admin reconciliation.
-- No payment provider/API is integrated. A reference is a claim, not proof of payment.

alter table public.payments
  add column if not exists customer_reference text,
  add column if not exists customer_provider text,
  add column if not exists customer_submitted_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists reviewed_at timestamptz,
  add column if not exists review_note text;

create index if not exists idx_payments_manual_review
  on public.payments(status, customer_submitted_at desc)
  where method = 'mobile_money';

create or replace function public.rpc_submit_mobile_money_reference(
  p_order_id uuid,
  p_reference text,
  p_provider text
) returns public.payments
language plpgsql security definer set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
  v_reference text := nullif(trim(p_reference), '');
  v_provider text := nullif(trim(p_provider), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_reference is null or length(v_reference) < 4 or length(v_reference) > 120 then
    raise exception 'La référence doit contenir entre 4 et 120 caractères';
  end if;
  if v_provider is null or length(v_provider) > 80 then
    raise exception 'Veuillez sélectionner le service Mobile Money utilisé';
  end if;

  select p.* into v_payment
  from public.payments p
  join public.orders o on o.id = p.order_id
  where p.order_id = p_order_id
    and p.user_id = auth.uid()
    and o.customer_id = auth.uid()
    and p.method = 'mobile_money'
  order by p.created_at desc limit 1
  for update of p;

  if not found then raise exception 'Paiement Mobile Money introuvable pour ce compte'; end if;
  if v_payment.status = 'paid' then raise exception 'Ce paiement est déjà confirmé'; end if;
  if v_payment.status not in ('pending', 'failed') then raise exception 'Ce paiement ne peut pas être soumis à nouveau'; end if;

  update public.payments
  set customer_reference = v_reference,
      customer_provider = v_provider,
      customer_submitted_at = now(),
      status = 'pending',
      reviewed_by = null,
      reviewed_at = null,
      review_note = null
  where id = v_payment.id
  returning * into v_payment;

  perform public.fn_log_audit(auth.uid(), 'customer', 'payment.mobile_money_reference_submitted',
    'payment', v_payment.id, null,
    jsonb_build_object('order_id', p_order_id, 'provider', v_provider));
  return v_payment;
end;
$$;

create or replace function public.rpc_review_manual_mobile_money(
  p_order_id uuid,
  p_approve boolean,
  p_note text default null
) returns public.payments
language plpgsql security definer set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
  v_role text;
  v_note text := nullif(trim(p_note), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select role into v_role from public.profiles where id = auth.uid();
  if v_role not in ('super_admin', 'city_admin') then raise exception 'Accès administrateur refusé'; end if;
  if not p_approve and v_note is null then raise exception 'Un motif est requis pour refuser le paiement'; end if;

  select p.* into v_payment
  from public.payments p
  join public.orders o on o.id = p.order_id
  where p.order_id = p_order_id
    and p.method = 'mobile_money'
    and p.customer_submitted_at is not null
    and p.status = 'pending'
    and o.payment_status <> 'paid'
  order by p.created_at desc limit 1
  for update of p;

  if not found then raise exception 'Aucun paiement soumis en attente de vérification'; end if;

  update public.payments
  set status = case when p_approve then 'paid'::public.payment_status else 'failed'::public.payment_status end,
      paid_at = case when p_approve then now() else null end,
      transaction_reference = case when p_approve then customer_reference else transaction_reference end,
      provider = case when p_approve then customer_provider else provider end,
      reviewed_by = auth.uid(), reviewed_at = now(), review_note = v_note
  where id = v_payment.id
  returning * into v_payment;

  update public.orders
  set payment_status = case when p_approve then 'paid'::public.payment_status else 'failed'::public.payment_status end
  where id = p_order_id;

  perform public.fn_log_audit(auth.uid(), v_role,
    case when p_approve then 'payment.mobile_money_manually_approved' else 'payment.mobile_money_manually_rejected' end,
    'payment', v_payment.id, null,
    jsonb_build_object('order_id', p_order_id, 'note', v_note, 'reference', v_payment.customer_reference));
  return v_payment;
end;
$$;

revoke all on function public.rpc_submit_mobile_money_reference(uuid, text, text) from public, anon;
grant execute on function public.rpc_submit_mobile_money_reference(uuid, text, text) to authenticated;
revoke all on function public.rpc_review_manual_mobile_money(uuid, boolean, text) from public, anon;
grant execute on function public.rpc_review_manual_mobile_money(uuid, boolean, text) to authenticated;
