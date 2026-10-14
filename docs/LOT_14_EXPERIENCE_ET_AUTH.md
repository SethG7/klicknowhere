# LOT 14 — Expérience client, menu mobile et authentification

## Fichiers à intégrer
- `src/components/klick/SiteHeader.tsx` — navigation mobile restructurée, liens plus faciles à toucher, sections « Commander » et « Mon espace », compteur panier, accès conditionnel à l'espace pro, déconnexion.
- `src/components/klick/RestaurantCard.tsx`, `src/lib/catalog.functions.ts`, `src/routes/index.tsx` — visuels de restaurants chargés depuis la base lorsqu’ils existent, cartes plus claires et CTA « Voir le menu ».
- `src/routes/auth.tsx` — écran de connexion/inscription simplifié, Google, Apple et Microsoft via l'intégration Lovable existante, erreurs visibles, états de chargement et récupération du mot de passe.
- `supabase/migrations/20261014000500_klick_super_admin_account.sql` — rôle `super_admin` pour `nkolaguni@gmail.com` uniquement quand l'adresse est confirmée par Supabase Auth, y compris si le compte existe déjà ou est créé plus tard.

## Intégration GitHub
Copier les chemins ci-dessus en conservant exactement leur arborescence. Ajouter la migration au dépôt puis l'appliquer au projet Supabase de test avant production.

## Configuration requise dans Supabase / Lovable
1. Auth > URL Configuration : définir l'URL de production comme Site URL et autoriser les URLs de redirection réellement utilisées (dont `/auth`). Ajouter les URLs de preview uniquement si elles sont nécessaires.
2. Auth > Providers : activer Google, Apple et Microsoft uniquement après avoir renseigné les identifiants OAuth correspondants. Afficher un bouton ne suffit pas à activer un fournisseur.
3. Google Cloud / Apple Developer / Microsoft Entra : enregistrer les URI de callback indiquées par le fournisseur d'authentification utilisé (Lovable Cloud ou Supabase Auth selon la configuration réelle). Ne pas mélanger les callbacks des deux systèmes.
4. Tester : inscription e-mail, confirmation, connexion, déconnexion, mot de passe oublié, Google sur mobile et desktop, puis un utilisateur client normal et le compte fondateur.
5. Après connexion avec `nkolaguni@gmail.com`, vérifier dans `public.profiles` que `role = 'super_admin'`. Le rôle n'est pas accordé au compte tant que l'e-mail n'est pas confirmé.

## Limites à connaître
- La migration ne peut pas activer à elle seule les fournisseurs OAuth : les secrets et URI de callback doivent être configurés dans les consoles externes.
- Le bouton « Aide pour une commande » renvoie au suivi KLICK. Aucun numéro WhatsApp de support n'est supposé dans le code.
- Le paiement Mobile Money reste manuel, conformément au périmètre actuel : aucune intégration de paiement n'est simulée ici.
- Cette livraison est un patch source + migration. La migration n'a pas été appliquée au projet Supabase distant et les parcours OAuth réels nécessitent les identifiants et URLs de production.
