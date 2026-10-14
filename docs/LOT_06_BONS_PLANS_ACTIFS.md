# KLICK — LOT 06 : filtrage des bons plans actifs

## Contexte
L'audit statique du projet a relevé que les requêtes de découverte et de fiche restaurant lisaient les bons plans sans filtrer explicitement leur statut actif et leurs dates de validité.

## Fichier modifié
- `src/lib/catalog.functions.ts`

## Changement
Les requêtes de bons plans dans `getDiscovery` et `getRestaurantBySlug` filtrent maintenant :
- `is_active = true` ;
- `starts_at` absent ou inférieur/égal à l'heure actuelle ;
- `ends_at` absent ou strictement supérieur à l'heure actuelle.

La ville est toujours filtrée par le périmètre demandé et les règles d'activation des villes existantes restent intactes. Aucune nouvelle restriction géographique n'est ajoutée.

## Hors périmètre
Ce lot ne modifie pas les commandes, les paiements, les commissions, les migrations SQL ni l'intégration Mobile Money. Les conditions récurrentes `days_of_week`, `daily_start` et `daily_end` ne sont pas évaluées dans ce patch ; elles nécessitent une règle horaire métier explicite et une définition du fuseau horaire de référence.

## Vérifications à effectuer
1. Un bon plan actif dont `starts_at` est dans le futur n'apparaît pas.
2. Un bon plan actif dont `ends_at` est passé n'apparaît pas.
3. Un bon plan actif sans date de début ou de fin reste admissible.
4. Un bon plan désactivé n'apparaît pas.
5. Vérifier le résultat sur la découverte et sur la fiche d'un restaurant.
6. Exécuter `npm run build` et `npm run lint` après intégration.

## Limites de validation
Ce patch a été préparé par modification statique du fichier source. Le build et les tests d'intégration n'ont pas été exécutés dans cet environnement.
