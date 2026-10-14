# KLICK — Lot 14 : parcours utilisateur, menu mobile et accès Super Admin

## Fichiers modifiés
- `src/components/klick/SiteHeader.tsx` : menu mobile regroupé par sections, accès rapide au panier, suivi, compte, espace professionnel et administration selon le rôle; déconnexion disponible.
- `src/routes/auth.tsx` : connexion Google, Apple et Microsoft via le connecteur Lovable existant, connexion/inscription par e-mail, réinitialisation de mot de passe.
- `supabase/migrations/20261014000500_klick_super_admin_bootstrap.sql` : attribution du rôle super_admin au compte vérifié `nkolaguni@gmail.com`, qu'il existe déjà ou qu'il soit créé plus tard.

## Important sur les connexions externes
Les boutons de fournisseurs sont des intégrations réelles seulement si les fournisseurs sont activés/configurés dans Lovable Cloud ou dans le fournisseur d'authentification raccordé. Configurer les URI de redirection de l'environnement de développement et de production. Les secrets OAuth ne doivent jamais être placés dans le code frontend.

## Super-admin
La migration ne promeut le compte que lorsque l'adresse correspond exactement à `nkolaguni@gmail.com` (sans distinction de casse) et que l'adresse est confirmée. Vérifier après migration dans Supabase Auth que le compte est confirmé, puis contrôler `profiles.role = 'super_admin'`. L'adresse e-mail doit appartenir au propriétaire du projet.

## Tests manuels obligatoires
1. Menu burger : ouvrir/fermer, liens Accueil, panier, suivi, compte, espaces partenaires, administration; tester sur mobile.
2. Panier : compteur correct, panier vide et panier avec articles.
3. Auth : connexion par e-mail, inscription, confirmation e-mail, Google; Apple/Microsoft uniquement après configuration de leurs fournisseurs.
4. Mot de passe oublié : e-mail reçu, lien redirigeant vers `/auth?mode=reset`, changement de mot de passe.
5. Rôles : client standard ne voit pas l'administration; compte vérifié `nkolaguni@gmail.com` devient super-admin; compte non confirmé n'est pas promu.
6. Tester en préproduction avant la production.

## Limite de validation
L'archive source a été inspectée et les modifications ont été préparées. Aucun build/lint ni test sur un projet Supabase distant n'a été exécuté dans cet environnement. Cette livraison n'affirme donc pas que les fournisseurs OAuth ou la migration sont déjà activés en production.
