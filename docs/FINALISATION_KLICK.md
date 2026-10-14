# KLICK — pack de finalisation ciblé

## Ce qui est réellement inclus dans ce patch
- Champs de candidature initiaux détaillés pour restaurants, livreurs indépendants et entreprises de livraison.
- Adresse de domicile obligatoire; adresse du restaurant obligatoire; adresse de l'entreprise obligatoire pour une entreprise de livraison.
- E-mail facultatif, ancienneté et présentation facultatives.
- Le portail professionnel ne permet plus de créer soi-même un accès; connexion uniquement.
- Migration additive pour les nouveaux champs et synchronisation des deux comptes Super Admin demandés, uniquement lorsque l'adresse Supabase est confirmée.

## Comptes Super Admin ciblés
- nkolaguni@gmail.com
- giuninkola99@gmail.com

La migration ne peut pas créer un mot de passe, activer un fournisseur OAuth ni confirmer une adresse à la place de Supabase. Les comptes doivent exister et être confirmés. Après application, vérifiez le rôle dans `public.profiles`.

## Authentification
Google est déjà implémenté dans `src/routes/auth.tsx` via l'intégration Lovable. Il faut activer/configurer Google dans le projet d'authentification réel et inscrire les URL de redirection de préproduction et production. Le patch ne peut pas effectuer cette configuration à distance. Les comptes partenaires n'ont plus d'auto-inscription.

## Installation
1. Faire un commit/sauvegarde du dépôt actuel.
2. Copier les quatre chemins du patch dans le dépôt.
3. Appliquer `supabase/migrations/20261014000800_partner_application_details_and_admins.sql` dans un environnement Supabase de test après les migrations existantes.
4. Tester une candidature restaurant, une candidature livreur indépendant et une candidature entreprise.
5. Vérifier que `/partner-login` ne propose plus de création de compte.
6. Tester les deux comptes Super Admin confirmés.
7. Exécuter `npm run build` et `npm run lint` dans l'environnement du projet.
8. Déployer en production seulement après validation.

## État de validation
Le patch est construit à partir du ZIP source reçu. Le build/lint et les tests Supabase ne sont pas exécutés ici. Ce patch ne prétend pas intégrer les anciens lots 13–18 : ils n'étaient pas présents dans le ZIP source disponible, donc ils doivent être fusionnés séparément s'ils existent dans ton dépôt GitHub. Il faut éviter d'appliquer des migrations de lots qui ne sont pas réellement dans le dépôt.
