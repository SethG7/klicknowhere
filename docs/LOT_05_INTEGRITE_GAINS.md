# KLICK — Lot 05 : intégrité de la confirmation des gains

## Fichier modifié
- `src/lib/operations.functions.ts`

## Problèmes traités
- `markEarningPaid` n'utilise plus le contrôle générique `assertAdmin`, qui autorise aussi les administrateurs de ville, alors que la politique RLS `earnings_admin_update` réserve la mise à jour des gains au super-administrateur.
- La fonction vérifie qu'un gain `pending` a réellement été modifié. Un identifiant inexistant, un gain déjà payé ou une ligne inaccessible ne renvoie plus un faux succès.
- `setDriverStatus` vérifie également qu'une ligne de livreur a réellement été modifiée.

## Limite métier importante
Le statut `paid` représente une confirmation interne. Il ne déclenche pas un transfert Mobile Money ou bancaire et ne constitue pas une preuve externe de paiement.

## Tests à effectuer dans un environnement de développement
1. `city_admin` essaie de confirmer un gain `pending` : refus côté serveur.
2. `super_admin` confirme un gain `pending` : le statut passe à `paid` et `paid_at` est renseigné.
3. Le même gain est soumis une seconde fois : la fonction renvoie une erreur et ne le modifie pas à nouveau.
4. Un UUID valide mais inexistant est soumis : la fonction renvoie une erreur.
5. Un administrateur tente de modifier un livreur hors de son périmètre : l'opération est refusée par les contrôles serveur/RLS.
6. Vérifier que l'interface affiche les erreurs sans présenter l'opération comme réussie.

## Validation avant fusion
- Exécuter `npm run build`.
- Exécuter `npm run lint`.
- Vérifier les politiques RLS sur la base de développement.
- Tester avec des comptes de rôle différents.

Les tests et le build n'ont pas été exécutés lors de la préparation de ce patch.
