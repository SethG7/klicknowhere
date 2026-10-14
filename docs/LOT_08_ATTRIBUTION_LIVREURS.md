# KLICK — LOT 08 : empêcher les doubles affectations de livreurs

## Pourquoi
L'audit du RPC existant `rpc_assign_driver` montre qu'il verrouille la commande et le livreur et vérifie le statut `ready`, la disponibilité, l'approbation et la ville. En revanche, il ne vérifiait pas si le livreur avait déjà une commande active. Son indicateur `is_available` restait également à `true` après l'affectation.

## Correctif
Migration ajoutée :
- `supabase/migrations/20261014000100_prevent_multiple_active_deliveries.sql`

La fonction RPC existante est remplacée sans modifier le parcours Kinshasa ni introduire d'API Mobile Money. Elle :
- garde les contrôles de statut, ville, rôle et disponibilité existants ;
- verrouille la ligne du livreur pour sérialiser les affectations concurrentes au même livreur ;
- refuse l'affectation si ce livreur possède déjà une commande `driver_assigned`, `picked_up` ou `on_the_way` ;
- met `drivers.is_available` à `false` après l'affectation ;
- conserve l'historique de statut, la ligne `deliveries` et le journal d'audit.

## Déploiement
1. Examiner la migration et vérifier qu'elle suit bien les migrations déjà appliquées dans l'environnement Supabase cible.
2. Appliquer la migration sur une base de développement/staging avant production.
3. Vérifier le résultat de `npm run build` et `npm run lint` côté application.
4. Tester les cas ci-dessous avant de fusionner.

## Tests obligatoires
1. Livreur approuvé et disponible, commande `ready`, même ville, aucune course active : affectation réussie ; disponibilité devient `false`.
2. Même livreur déjà sur une commande `driver_assigned` : deuxième affectation refusée.
3. Même livreur sur une commande `picked_up` ou `on_the_way` : nouvelle affectation refusée.
4. Deux requêtes concurrentes tentent d'affecter deux commandes au même livreur : une seule doit réussir.
5. Livreur indisponible, non approuvé ou d'une autre ville : affectation refusée.
6. Commande non `ready` ou déjà attribuée : affectation refusée.
7. Super-administrateur et administrateur de ville conservent leurs règles d'autorisation existantes.

## Notes
- La disponibilité n'est pas automatiquement réactivée à la livraison ; le livreur peut la réactiver via le mécanisme existant quand il est prêt à reprendre des courses.
- Cette migration ne change pas les transitions de statut ni les règles de paiement manuel.
- La compilation et les tests de base de données n'ont pas été exécutés lors de la préparation du patch.
