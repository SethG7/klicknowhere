# KLICK — LOT 12 : administration des zones et frais de livraison

## Objectif
Permettre à l'administration KLICK de configurer les communes/zones desservies, les frais de livraison et le délai estimé, sans laisser ces paramètres aux restaurants.

## Fichiers de ce lot
- `src/lib/operations.functions.ts` : charge les zones visibles dans l'espace admin et ajoute l'enregistrement sécurisé d'une zone.
- `src/routes/_authenticated/operations.tsx` : ajoute le module « Zones & frais de livraison » au tableau de bord admin.

## Fonctionnement
- Ajout et modification d'une zone.
- Champs : ville, nom de la commune/zone, description facultative, frais en CDF, délai estimé et activation/désactivation.
- Le serveur vérifie le rôle administrateur et, pour un `city_admin`, l'affectation à la ville concernée.
- Les zones sont soumises aux politiques RLS existantes de `delivery_zones`.
- Les administrateurs de ville ne voient que les villes qui leur sont attribuées dans ce tableau de bord.
- Aucune suppression physique n'est proposée : désactiver une zone évite de casser les anciennes commandes qui y font référence.

## Déploiement GitHub
1. Décompresser le ZIP.
2. Dans le dépôt GitHub KLICK, remplacer les deux fichiers en conservant exactement leurs chemins.
3. Vérifier que le lot 10 et les lots précédents nécessaires sont déjà intégrés.
4. Commit/push, puis laisser l'environnement de déploiement reconstruire le projet.
5. Tester avec un compte `super_admin`, puis avec un compte `city_admin` affecté à Kinshasa.

## Vérifications avant production
- Confirmer que Kinshasa est la seule ville activée pour le lancement si le périmètre doit rester strictement Kinshasa.
- Confirmer qu'un `city_admin` possède une ligne dans `city_admins` pour Kinshasa.
- Tester ajout, modification, désactivation, frais à zéro, doublon de nom et accès refusé à une autre ville.
- Vérifier le calcul des frais lors de la création d'une commande : ce lot administre les zones, mais ne remplace pas les contrôles côté serveur du calcul de commande.

## Limite de validation
Le code n'a pas été compilé ni testé contre le projet Supabase réel dans cet environnement. Tester d'abord sur un environnement de préproduction.
