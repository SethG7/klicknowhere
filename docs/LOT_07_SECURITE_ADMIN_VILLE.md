# LOT 07 — Sécurité des opérations administrateur

## Objectif
Limiter les données et actions des administrateurs de ville à leurs villes assignées, sans modifier le périmètre produit KLICK (RDC, lancement à Kinshasa) ni ajouter d'intégration Mobile Money.

## Fichier remplacé
- `src/lib/operations.functions.ts`

## Changements
1. Le tableau de bord d'un `city_admin` récupère ses villes depuis `city_admins` puis limite les commandes, livreurs et dossiers en attente à ces villes.
2. Les gains visibles par un administrateur de ville sont limités aux livreurs de ses villes assignées. Le `super_admin` conserve la vue globale.
3. Un administrateur de ville ne peut pas suspendre/réactiver un livreur hors de son périmètre.
4. La suspension d'un livreur le rend également indisponible.
5. Le paiement d'un gain vérifie l'existence du gain, son statut `pending`, et le périmètre du city admin. Si le gain a déjà été traité, la fonction renvoie une erreur explicite au lieu d'afficher un faux succès.

## Installation GitHub
1. Téléchargez et décompressez `KLICK_patch_GitHub_lot_07.zip`.
2. Dans votre dépôt GitHub KLICK, ouvrez `src/lib/operations.functions.ts`.
3. Remplacez tout le contenu du fichier par celui du patch, puis enregistrez/committez.
4. Ajoutez le fichier de documentation `docs/LOT_07_SECURITE_ADMIN_VILLE.md`.
5. Message de commit conseillé : `fix(ops): scope city admin access and payouts`.

## À vérifier après déploiement
- Un `city_admin` assigné à une seule ville ne voit que les commandes, livreurs, dossiers et gains de cette ville.
- Un `city_admin` sans affectation ne voit aucune donnée opérationnelle de ville.
- Un `super_admin` conserve l'accès global.
- Suspendre un livreur force `is_available = false`.
- Un gain déjà payé ne peut pas être marqué payé une seconde fois.

## Limites
- Ce lot ne remplace pas les politiques RLS Supabase : elles doivent continuer à être maintenues comme seconde barrière de sécurité.
- Le build et les tests automatisés n'ont pas été exécutés, car les dépendances (`node_modules`) ne sont pas installées dans l'environnement d'analyse.
- Vérifier l'interface admin après commit, notamment si elle attend des données globales pour un compte `city_admin`.
