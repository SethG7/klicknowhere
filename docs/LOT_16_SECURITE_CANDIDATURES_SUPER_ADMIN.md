# KLICK — LOT 16 : sécurité des candidatures et activation Super Admin

## Ce que ce lot corrige

1. **Une candidature ne peut plus s'auto-approuver à l'insertion.** Les champs de contrôle `status`, `reviewed_by`, `reviewed_at` et `rejection_reason` sont normalisés côté base de données pour toute nouvelle candidature restaurant ou livreur. Une nouvelle candidature commence toujours en `pending`.
2. **Activation Super Admin après confirmation de l'e-mail.** Le mécanisme ne dépend plus uniquement d'une modification de la ligne `profiles` : un trigger sur `auth.users` prend aussi en charge la confirmation tardive de l'adresse.
3. **Deux adresses exactes uniquement :** `nkolaguni@gmail.com` et `giuninkola99@gmail.com`. Le compte doit exister dans Supabase Auth et l'adresse doit être confirmée. Le lot ne crée pas les comptes Auth et ne configure pas Google OAuth.
4. **Retrait du rôle réservé si une adresse autorisée change.** Si un de ces comptes modifie son e-mail vers une autre adresse, son rôle `super_admin` est ramené à `customer`.

## Fichier

`supabase/migrations/20261014000600_secure_partner_applications_and_admin_bootstrap.sql`

## Ordre d'intégration

- Conserver le code existant et les lots précédents.
- Ajouter cette migration après `20261014000500_partner_applications_and_admin_access.sql`.
- Lancer d'abord sur un projet Supabase de test, après sauvegarde et vérification du schéma réel.
- Vérifier les deux comptes autorisés et leurs e-mails confirmés avant de considérer l'accès Super Admin opérationnel.

## Tests de recette indispensables

1. Soumettre une candidature restaurant en envoyant volontairement `status=approved`, un `reviewed_by` et un `rejection_reason` : la ligne créée doit être `pending`, sans réviseur ni motif de rejet.
2. Répéter le test pour une candidature livreur.
3. Créer un compte `nkolaguni@gmail.com` non confirmé : il ne doit pas obtenir le rôle réservé.
4. Confirmer cet e-mail après création du profil : le profil doit devenir `super_admin`.
5. Répéter avec `giuninkola99@gmail.com`.
6. Créer/confirmer un compte avec une adresse différente et tenter d'envoyer `role=super_admin` depuis le client : il ne doit pas obtenir ce rôle.
7. Changer l'e-mail d'un compte autorisé vers une adresse non autorisée : le rôle réservé doit être retiré.
8. Vérifier que les utilisateurs ordinaires ne peuvent lire/modifier que leurs propres candidatures et que l'équipe KLICK garde l'accès de revue via les mécanismes administratifs existants.

## Limites connues

- Cette livraison n'a pas été exécutée contre le projet Supabase réel. La migration doit être validée en staging.
- Les règles RLS/grants déjà en place ne sont pas remplacées par ce lot.
- Le paiement Mobile Money reste manuel ; aucune intégration opérateur n'est ajoutée.
- Le périmètre produit reste Kinshasa, RDC.
