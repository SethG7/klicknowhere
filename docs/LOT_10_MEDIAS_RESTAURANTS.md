# KLICK — LOT 10 : stockage sécurisé des médias restaurants

## Ce que le code possède déjà
Les colonnes `restaurants.logo_url`, `restaurants.cover_url` et `products.image_url` existent déjà. Le catalogue sait lire et afficher ces URL. En revanche, aucune configuration Storage n'a été trouvée dans les migrations du ZIP source pour permettre aux équipes restaurants de téléverser leurs images.

## Ce que cette migration ajoute
- Bucket public `klick-restaurant-media` pour l'affichage du catalogue.
- Taille maximale par fichier : 5 Mio.
- Types MIME autorisés : JPEG, PNG et WebP.
- Convention de chemin : `<restaurant-uuid>/logo/<fichier>`, `<restaurant-uuid>/cover/<fichier>`, `<restaurant-uuid>/dishes/<fichier>`.
- Lecture publique ; ajout, modification et suppression uniquement par un membre du restaurant propriétaire du dossier.

## Important — ce lot ne crée pas encore le formulaire d'upload dans l'interface
Cette migration prépare et sécurise le stockage. Il faut ensuite connecter le tableau de bord restaurant au bucket : sélectionner un fichier, téléverser, récupérer l'URL publique et enregistrer cette URL dans `restaurants.logo_url`, `restaurants.cover_url` ou `products.image_url`. Ne pas annoncer le parcours d'upload comme complet avant ce travail d'interface.

## Livraison et frais
Le modèle existant comprend déjà `delivery_zones` avec `name`, `description`, `delivery_fee`, `estimated_delivery_minutes` et `is_active`. Les frais sont donc portés par les zones et peuvent être administrés via les droits RLS existants. La création/édition des zones doit rester une action d'administration KLICK ; ne pas laisser un restaurant fixer les frais de livraison.

## Commissions et délégation des pouvoirs
Le projet contient déjà `restaurants.commission_rate` et une fonction de modification réservée actuellement au `super_admin`. Le super-admin conserve le contrôle global. Le système actuel gère la délégation de rôles, mais pas encore une matrice complète de permissions granulaires par action. Ne pas prétendre qu'une délégation fine des droits est terminée : elle doit faire l'objet d'un lot distinct avec audit et tests d'autorisation.

## Déploiement
1. Examiner la migration sur une instance Supabase de test.
2. Vérifier qu'aucune policy de même nom n'existe déjà dans le projet cible.
3. Appliquer la migration en staging.
4. Tester les uploads avec deux restaurants différents et confirmer qu'un membre ne peut pas écrire dans le dossier de l'autre.
5. Ne déployer en production qu'après vérification.

## Limites
Le build de l'application et les tests Supabase ne sont pas exécutés dans le cadre de la préparation de ce patch. Le formulaire d'upload, la compression/redimensionnement côté client et les contrôles UX ne sont pas inclus.
