# KLICK — Lot 04 : contrôles de confirmation des gains

## Fichier modifié
- `src/lib/operations.functions.ts`

## Ce que fait ce lot
- La modification du statut d'un livreur vérifie maintenant qu'une ligne a réellement été modifiée. Une mise à jour vide ou refusée ne renvoie plus un faux succès.
- La confirmation d'un gain payé est explicitement réservée au rôle `super_admin`, en cohérence avec la politique RLS déclarée dans `drizzle/migrations/0002_admin_fleet_policies.sql`.
- La confirmation exige que le gain soit encore `pending`.
- La fonction vérifie le résultat de la mise à jour et renvoie une erreur explicite si le gain n'existe pas, est déjà payé ou n'est pas accessible.

## Ce que ce lot ne fait pas
- Il n'effectue aucun transfert Mobile Money ou bancaire.
- Il ne prouve pas qu'un transfert a eu lieu : il marque seulement le statut interne du gain.
- Il ne modifie pas les formules de commission, le schéma SQL ou les migrations.

## Tests manuels requis
1. Avec un compte `city_admin`, tenter de confirmer un gain : l'action doit être refusée côté serveur.
2. Avec un compte `super_admin`, confirmer un gain `pending` : le statut doit passer à `paid` et `paid_at` doit être renseigné.
3. Répéter l'action sur le même gain : la seconde requête doit renvoyer une erreur « déjà payé » ou équivalente.
4. Fournir un UUID valide mais inexistant : la fonction doit renvoyer une erreur, pas `{ ok: true }`.
5. Avec un administrateur de ville, modifier un livreur de sa ville, puis tenter un livreur d'une autre ville : la politique RLS doit limiter la seconde opération.
6. Vérifier que l'interface affiche les erreurs sans présenter un paiement comme réussi.

## Validation technique
Exécuter `npm run build` et `npm run lint` après intégration. Ces commandes n'ont pas été exécutées lors de la préparation de ce patch.
