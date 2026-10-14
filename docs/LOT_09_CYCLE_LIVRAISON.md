# KLICK — LOT 09 : cycle de livraison et gains livreur

## Fichier
- `supabase/migrations/20261014000200_harden_delivery_completion_and_driver_release.sql`

## Correctifs ciblés
- Vérifie qu'une livraison existe et correspond au livreur de la commande avant `picked_up`, `on_the_way` ou `delivered`.
- Synchronise les statuts et horodatages de `deliveries` avec les étapes de la commande.
- À la livraison terminée, crée les gains livreur une seule fois grâce à la contrainte unique existante sur `driver_earnings.delivery_id`.
- Réactive un livreur approuvé après livraison ou annulation d'une commande qui lui était attribuée.
- Marque une livraison interrompue `failed`, valeur déjà présente dans l'enum `delivery_status`.
- Préserve les contrôles d'autorisation déjà utilisés par `rpc_update_order_status` et révoque l'exécution à `anon`.

## Installation
1. Vérifier que le LOT 08 est bien intégré si vous souhaitez aussi bloquer les affectations multiples et rendre le livreur indisponible pendant une course.
2. Ajouter le fichier de migration à GitHub sans renommer les migrations déjà appliquées.
3. Appliquer la migration dans un environnement de test Supabase avant la production.
4. Tester les scénarios ci-dessous avant déploiement.

## Tests de recette à effectuer
- Un livreur assigné à une commande ne peut pas faire avancer une commande sans ligne `deliveries` cohérente.
- `driver_assigned -> picked_up -> on_the_way -> delivered` met à jour `deliveries` et produit exactement une ligne `driver_earnings`.
- Un second appel de finalisation ne crée pas un doublon (la transition d'état doit toutefois être refusée par la machine à états).
- Une annulation après affectation marque la livraison `failed` et réactive uniquement un livreur au statut `approved`.
- Un utilisateur non autorisé ne peut pas modifier le statut d'une commande.
- Les appels internes avec `auth.uid() IS NULL` sont testés avec le contexte de service réellement utilisé par le projet.

## Limites
Cette livraison est une migration SQL rédigée et vérifiée statiquement. Elle n'a pas été exécutée contre le projet Supabase réel; aucune garantie de compilation ou d'intégration n'est revendiquée avant application et tests. Le comportement d'annulation après enlèvement est conservé selon la machine à états existante; la politique opérationnelle doit être validée.
