# KLICK — LOT 11 : interface de gestion des médias restaurant

## Fichiers applicatifs remplacés
- `src/lib/operations.functions.ts`
- `src/components/klick/RestaurantSpace.tsx`

## Migration requise
- `supabase/migrations/20261014000300_restaurant_media_storage.sql`

La migration configure le bucket public `klick-restaurant-media` avec une limite de 5 Mo et les formats JPEG/PNG/WebP. Si cette migration du LOT 10 a déjà été appliquée sur l'instance, ne pas la rejouer manuellement ni créer une seconde entrée d'historique.

## Fonctionnalités
- Nouvel onglet d'identité visuelle pour le propriétaire : logo et couverture.
- Téléversement, remplacement et retrait ; URL enregistrée dans `restaurants.logo_url` ou `restaurants.cover_url`.
- Affichage de la photo du plat dans la liste du menu.
- Champ URL et téléversement direct de photo pour un plat existant ; URL enregistrée dans `products.image_url`.
- Vérification de format JPEG/PNG/WebP et limite de 5 Mo côté interface.
- Modifications du logo/de la couverture réservées au propriétaire via contrôle serveur.

## À savoir
- Pour un nouveau plat, enregistrer d'abord le plat, puis le rouvrir pour téléverser sa photo.
- Les fichiers Storage remplacés ou retirés ne sont pas supprimés automatiquement. Une routine de nettoyage des fichiers orphelins devra être un lot séparé.
- Vérifier que les politiques Storage n'existent pas déjà sous ces noms avant d'appliquer la migration.

## Vérifications
1. Le propriétaire peut ajouter/remplacer/retirer logo et couverture.
2. Le manager ne voit pas l'onglet d'identité visuelle.
3. Un membre peut téléverser une photo uniquement dans le dossier de son restaurant.
4. Un compte d'un autre restaurant ne peut pas écrire dans ce dossier.
5. Le catalogue public affiche les médias après rafraîchissement.
6. `npm run build` et `npm run lint` passent avant fusion.

## Limites
Le build, lint et tests Supabase n'ont pas été exécutés dans cet environnement. Tester d'abord en développement/staging.
