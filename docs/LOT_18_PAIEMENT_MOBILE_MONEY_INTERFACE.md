# LOT 18 — Interface Mobile Money manuelle

## Inclus
- Formulaire côté client pour soumettre opérateur et référence de transaction sur la page détail de commande.
- Le paiement reste en attente tant qu’un administrateur ne l’a pas vérifié.
- Module « Paiements Mobile Money » dans l’espace administration : références en attente, montant, opérateur, référence, confirmation ou refus avec motif.
- Vérification de rôle côté serveur pour les actions d’administration.

## Prérequis obligatoire
Appliquer d’abord la migration du LOT 17 : `supabase/migrations/20261014000700_manual_mobile_money_reconciliation.sql`. Elle crée les colonnes et RPC utilisés par cette interface.

## Installation
Copier les fichiers du ZIP aux mêmes chemins dans le dépôt GitHub, puis exécuter les migrations Supabase dans l’ordre. Déployer ensuite l’application.

## Vérifications à faire avant production
1. Tester la soumission avec un compte client authentifié.
2. Vérifier qu’une référence ne passe jamais automatiquement le paiement à « payé ».
3. Tester la confirmation et le refus depuis un compte `city_admin` ou `super_admin`.
4. Vérifier que les comptes client, restaurant et livreur ne peuvent pas appeler la fonction de revue.
5. Exécuter `npm run build` et les tests du projet dans l’environnement de déploiement.

Le ZIP a été assemblé à partir des fichiers source disponibles. La compilation et les tests d’intégration n’ont pas été exécutés ici.
