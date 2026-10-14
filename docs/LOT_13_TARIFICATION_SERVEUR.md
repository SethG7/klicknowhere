# KLICK — LOT 13 : sécurisation du calcul des frais et commissions

## Ce que corrige cette migration

La base de données devient l'autorité finale pour les valeurs financières d'une commande :
- la zone doit appartenir à la ville du restaurant et être active ;
- les frais de livraison sont relus depuis `delivery_zones`, jamais acceptés depuis le navigateur ;
- la ville de la commande doit correspondre à celle du restaurant ;
- le taux de commission vient de la configuration du restaurant ;
- la commission est calculée sur le sous-total des plats, hors livraison ;
- le total est recalculé à partir du sous-total, des frais et de la remise ;
- une remise invalide ou supérieure au montant disponible est rejetée.

La fonction est déclenchée par le trigger existant `trg_order_financials` sur `orders`. La migration remplace le corps de `fn_set_order_financials()` sans supprimer le trigger.

## Fichier
- `supabase/migrations/20261014000400_authoritative_order_pricing.sql`

## Installation
1. Vérifier dans le dépôt que les migrations précédentes définissent bien `delivery_zones.is_active`, `orders.delivery_zone_id`, `restaurants.commission_rate` et le trigger `trg_order_financials`.
2. Appliquer cette migration sur un projet Supabase de développement/staging.
3. Exécuter les tests de la liste ci-dessous.
4. Appliquer en production uniquement après validation.

## Tests indispensables
1. Commande avec zone active et tarif connu : le tarif enregistré correspond à la base.
2. Tentative d'utiliser une zone désactivée : commande rejetée.
3. Zone d'une autre ville : commande rejetée.
4. Valeur de frais manipulée côté client : le montant stocké reste celui de la zone.
5. Commission : calculée sur `subtotal` et non sur `total`.
6. Total : `subtotal + delivery_fee - discount`.
7. Restaurant non approuvé : commande rejetée.
8. Remise négative ou supérieure au montant : commande rejetée.
9. Vérifier les commandes invitées et authentifiées ainsi que les méthodes de paiement actuellement prévues.

## Limite
Cette migration ne fournit pas une intégration Mobile Money. Les confirmations de paiement restent manuelles selon le processus actuel. Elle ne modifie pas non plus la politique de commission : elle applique le taux déjà configuré pour chaque restaurant.

## Validation technique
La migration a été relue structurellement mais n'a pas été exécutée contre le projet Supabase réel. Tester en staging et conserver une sauvegarde avant production.
