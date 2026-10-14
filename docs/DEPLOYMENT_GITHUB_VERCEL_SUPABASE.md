# KLICK — déploiement de test GitHub + Vercel + Supabase

Ce dépôt utilise TanStack Start, React, Vite, Nitro et Supabase. Le déploiement Vercel doit utiliser le preset **TanStack Start**. Les tests de recette doivent être faits sur une base de staging séparée de la production.

## 1. Vérifier le projet Supabase cible

Le ZIP source présentait deux références différentes : l'URL frontend pointait vers `yisunyyefdcvxlxvvjzm`, tandis que `supabase/config.toml` pointait vers `kpihpplvrcjqcmctchcf`. La configuration CLI a été alignée sur la référence de l'URL frontend. Avant d'appliquer les migrations, vérifiez dans le tableau de bord Supabase que le projet choisi est bien celui prévu pour KLICK. Ne poussez pas les migrations sur une base de production sans sauvegarde.

## 2. Créer le dépôt GitHub

1. Créez un dépôt privé GitHub pour KLICK.
2. Décompressez ce paquet, puis envoyez le contenu du dossier racine dans le dépôt (pas le dossier parent du ZIP).
3. Vérifiez que `.env` n'est pas envoyé. Seul `.env.example` doit être versionné.
4. Conservez `bun.lock` avec les modifications du `package.json` : les installations CI utilisent `bun install --frozen-lockfile`.
5. La vérification GitHub Actions s'exécute à chaque push et pull request : typecheck, build et lint. Si elle échoue, lisez le premier message d'erreur et corrigez avant de déployer en production.

## 3. Variables d'environnement Vercel

Dans **Vercel → Project → Settings → Environment Variables**, ajoutez les valeurs suivantes pour **Preview** et **Development**. Pour Production, ne les ajoutez que si vous décidez d'y déployer réellement.

- `SUPABASE_URL` : URL du projet Supabase de test, par exemple `https://<project-ref>.supabase.co`.
- `SUPABASE_PUBLISHABLE_KEY` : clé publishable Supabase correspondante.
- `VITE_SUPABASE_URL` : même URL Supabase.
- `VITE_SUPABASE_PUBLISHABLE_KEY` : même clé publishable.

Les variables `VITE_*` sont visibles dans le navigateur : elles doivent contenir uniquement l'URL et la clé **publishable**, jamais de secret. N'ajoutez `SUPABASE_SERVICE_ROLE_KEY` que si une fonction serveur de confiance l'exige explicitement; ne la préfixez jamais par `VITE_` et ne la commitez jamais.

Après toute modification de variable, relancez un déploiement, car les builds déjà créés ne prennent pas automatiquement les nouvelles valeurs.

## 4. Importer sur Vercel

1. Dans Vercel, créez un projet à partir du dépôt GitHub.
2. Vérifiez que le framework est détecté comme **TanStack Start**. `vercel.json` le précise explicitement.
3. Laissez Vercel détecter la commande de build et le répertoire de sortie. Le script `build` est `vite build`.
4. Ajoutez les variables Supabase de staging avant le premier déploiement.
5. Déployez d'abord en Preview. Ne basculez pas le domaine de production pour ce test.

Référence officielle : [Déployer TanStack Start sur Vercel](https://vercel.com/kb/guide/deploy-a-tanstack-start-app-to-vercel).

## 5. Appliquer les migrations Supabase

**Ordre obligatoire :** sauvegarde ou projet de staging vierge → vérifier le projet lié → appliquer les migrations → contrôler les tables et politiques → tester l'application.

Depuis la racine du dépôt, avec Supabase CLI installé et authentifié :

```bash
supabase login
supabase link --project-ref <PROJECT_REF_DE_STAGING>
supabase db push
```

Le dossier `supabase/migrations/` contient les migrations historiques puis la migration additive `20261014000800_partner_application_details_and_admins.sql`. N'appliquez pas uniquement cette dernière sur une base vide : elle complète le schéma historique.

Après migration, vérifiez dans Supabase que les tables `profiles`, `cities`, `restaurants`, `restaurant_applications` et `driver_applications` existent, que RLS est activé, et qu'au moins une ville est active. Le formulaire de candidature ne peut pas être testé sans ville active.

## 6. Activer l'authentification

Dans **Supabase → Authentication → URL Configuration** :

- Site URL : URL de votre déploiement de test.
- Redirect URLs : ajoutez `http://localhost:3000/auth` et l'URL Preview Vercel exacte terminée par `/auth`. Ajoutez aussi le domaine de production seulement lorsqu'il existe.

Dans **Authentication → Providers**, activez Google et configurez les identifiants OAuth Google. Les URI de redirection/callback affichées par Supabase doivent également être configurées dans Google Cloud Console. Le code utilise maintenant directement `supabase.auth.signInWithOAuth`, sans dépendance à l'authentification propriétaire de Lovable.

Les utilisateurs peuvent créer un compte client. L'accès partenaire reste une connexion réservée aux comptes créés/activés par l'administration; une candidature n'accorde pas automatiquement un accès professionnel.

## 7. Comptes Super Admin

Les adresses réservées au Super Admin sont :

- `nkolaguni@gmail.com`
- `giuninkola99@gmail.com`

Créez ces comptes dans Supabase Auth et confirmez leurs adresses. Ensuite, ouvrez le SQL Editor du **projet de test vérifié**, exécutez `supabase/ops/bootstrap_super_admins.sql`, puis vérifiez que les deux profils retournés ont `role = super_admin` et `status = active`. Le script n'invente pas de comptes et ne crée aucun mot de passe.

Ne partagez jamais la clé service role ni les mots de passe. La promotion des rôles doit rester une opération administrative explicite.

## 8. Checklist de recette avant d'envisager la production

- [ ] La page d'accueil s'ouvre sur l'URL Preview Vercel.
- [ ] Les routes client se chargent sans 404 et sans erreur SSR.
- [ ] Inscription e-mail, confirmation, connexion et déconnexion fonctionnent.
- [ ] Connexion Google fonctionne depuis le domaine Preview.
- [ ] Un client ne peut consulter que ses données personnelles selon les politiques RLS.
- [ ] Le catalogue ne montre que les restaurants approuvés d'une ville active.
- [ ] Le formulaire de candidature exige nom complet, téléphone et adresse du domicile.
- [ ] Une candidature restaurant exige aussi nom et adresse du restaurant.
- [ ] Une entreprise de livraison exige son nom et son adresse professionnelle.
- [ ] Les candidatures sont persistées avec le statut `pending` et visibles par leur demandeur.
- [ ] Un compte client ne peut pas ouvrir l'espace opérations.
- [ ] Les comptes Super Admin ont les bons rôles et les autres comptes ne peuvent pas s'attribuer ce rôle.
- [ ] Les zones et frais de livraison sont configurés pour Kinshasa; les paiements Mobile Money restent manuels, conformément au périmètre actuel.
- [ ] Les logs Vercel et Supabase ne contiennent pas de clé secrète ni de données personnelles inutiles.

## 9. Limites honnêtes de cette livraison

Le code et les fichiers de configuration ont été préparés pour un déploiement reproductible, mais ce paquet n'a pas pu être compilé dans cet environnement : l'installation des dépendances a expiré. Les migrations n'ont pas été exécutées sur le projet Supabase distant et aucun déploiement Vercel/GitHub n'a été lancé. Le workflow GitHub et la première Preview doivent donc servir de contrôle réel; ne considérez pas l'application comme certifiée en production avant que toute la checklist soit passée.
