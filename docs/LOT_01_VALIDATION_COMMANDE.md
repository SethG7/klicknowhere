# KLICK — Lot 01 : validation des commandes et panier

## Fichiers de ce lot
- `src/lib/order-validation.ts` — nouveau schéma de validation Zod.
- `src/lib/catalog.functions.ts` — validation des entrées publiques et commandes invitées.
- `src/lib/account.functions.ts` — validation des commandes des utilisateurs connectés.
- `src/lib/cart.tsx` — validation du panier restauré et limites de quantité.

## Tests manuels à exécuter
- Créer une commande invitée avec des données valides.
- Créer une commande avec un compte connecté.
- Vérifier qu'un panier vide est refusé.
- Vérifier qu'une quantité 0, négative, décimale ou supérieure à 50 est refusée.
- Vérifier qu'un UUID produit invalide est refusé.
- Vérifier que les doublons d'un même produit sont refusés côté serveur.
- Vérifier qu'un téléphone invalide est refusé.
- Vérifier qu'un numéro de commande au mauvais format est refusé.
- Modifier manuellement le contenu `klick.cart` dans le stockage du navigateur et confirmer que le panier corrompu est supprimé.
- Vérifier que les prix définitifs sont toujours recalculés côté SQL (`rpc_create_order`).

## Validation avant fusion
1. Vérifier les différences dans GitHub.
2. Lancer `npm run build` et `npm run lint` dans l'environnement du dépôt.
3. Exécuter les tests manuels ci-dessus en développement.
4. Ne pas déployer si le build échoue.

Ce document décrit des tests à réaliser. Il ne certifie pas qu'ils ont déjà été exécutés.
