# KLICK — Lot 03 : contrôles administratifs et confirmation des gains

## Fichier modifié
- `src/lib/operations.functions.ts`

## Changements
1. `setDriverStatus` vérifie désormais qu'une ligne a effectivement été mise à jour. Si le livreur n'existe pas ou se trouve hors du périmètre autorisé par les politiques RLS, la fonction renvoie une erreur explicite au lieu de signaler un succès trompeur.
2. `markEarningPaid` est réservé explicitement au rôle `super_admin`, conformément à la politique RLS déclarée dans `drizzle/migrations/0002_admin_fleet_policies.sql`.
3. La confirmation d'un gain payé vérifie qu'une ligne en statut `pending` a réellement été modifiée. Un gain déjà payé, inexistant ou inaccessible renvoie une erreur.

## À vérifier après intégration
- Un `city_admin` peut gérer un livreur de sa ville, mais ne peut pas confirmer un paiement de gain.
- Un `super_admin` peut confirmer un gain encore `pending`.
- Un gain déjà `paid` ne peut pas être confirmé une seconde fois.
- Un identifiant de gain inexistant ne produit pas un faux succès.
- Un administrateur de ville ne peut pas modifier un livreur hors de son périmètre RLS.
- La page d'administration gère correctement les erreurs renvoyées par ces fonctions.

## Limites
Ce changement confirme un statut de paiement dans la base ; il ne réalise pas un transfert Mobile Money ou bancaire. Le transfert réel et sa preuve doivent être gérés séparément si le produit les prend en charge.

Aucun build ni test automatisé n'a été exécuté lors de la préparation de ce patch. Exécuter `npm run build` et `npm run lint`, puis effectuer les tests manuels sur un environnement de développement avant fusion.
