# KLICK — LOT 17 : déclaration et rapprochement manuel Mobile Money

## Fonctionnalité base de données
Ce lot ajoute un flux backend pour le lancement à Kinshasa sans API de paiement :
- le client connecté soumet le nom du service Mobile Money et sa référence pour sa propre commande ;
- la référence ne marque jamais automatiquement la commande comme payée ;
- un `super_admin` ou `city_admin` examine la soumission et peut confirmer ou refuser ;
- un refus exige un motif ;
- chaque décision est inscrite dans `fn_log_audit` ;
- les données de soumission et de revue restent sur la ligne `payments`.

## RPC
- `rpc_submit_mobile_money_reference(order_id, reference, provider)` — rôle `authenticated`, vérifie que la commande et le paiement appartiennent au client.
- `rpc_review_manual_mobile_money(order_id, approve, note)` — vérifie le rôle administrateur côté base de données.

## Déploiement
1. Examiner le schéma et les fonctions existantes dans le dépôt.
2. Appliquer en environnement Supabase de test avant la production.
3. Tester avec deux clients distincts, un administrateur et un compte sans rôle admin.
4. Vérifier que la soumission d'une référence ne marque pas le paiement payé et qu'un client ne peut pas soumettre pour une commande tierce.
5. Vérifier acceptation, refus avec motif, refus sans motif, double confirmation et audit.

## Important
- La migration fournit le socle RPC/base de données ; elle ne branche pas encore les formulaires de l'interface client ni la file de revue dans le tableau de bord. Ces interfaces doivent appeler les RPC et être livrées dans le lot UI suivant.
- Les références fournies par le client ne sont pas une preuve de transfert. L'équipe doit vérifier la transaction dans son canal Mobile Money avant d'approuver.
- Les fonctions supposent que le schéma existant contient `fn_log_audit`, `profiles.role`, `payments.user_id`, `orders.customer_id`, `orders.payment_status` et les valeurs d'enum utilisées. Confirmer en staging avant production.
- Pas d'API Mobile Money ni de webhook activé par ce lot.
