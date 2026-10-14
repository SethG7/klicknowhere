# KLICK — paquet intégré pour GitHub

Cette archive regroupe le code source de départ, les lots 01 à 18 retrouvés dans les fichiers de travail, les corrections de finalisation des candidatures et les fichiers de préparation GitHub/Vercel/Supabase. Le périmètre MVP est Kinshasa, RDC. Les paiements Mobile Money restent manuels.

## Pour l'import GitHub
1. Créez une branche de test ou un dépôt privé neuf.
2. Envoyez le contenu de ce dossier racine, pas le dossier parent.
3. Ne publiez jamais `.env`, les clés privées ou les mots de passe.
4. Lisez `docs/DEPLOYMENT_GITHUB_VERCEL_SUPABASE.md` avant de relier Supabase ou Vercel.
5. Vérifiez le workflow GitHub Actions et le résultat du build Preview.

## Attention aux migrations
Les lots historiques contiennent plusieurs migrations SQL qui ont été conçues séparément. Avant d'exécuter les migrations sur une base distante, vérifiez leurs versions, leurs dépendances et leur compatibilité avec l'état réel de la base. N'appliquez pas les migrations en production sans sauvegarde.

## État des validations
L'archive est une consolidation de fichiers, pas une preuve de compilation réussie. L'installation des dépendances, le build complet, les tests OAuth et l'exécution sur Supabase distant doivent être validés par GitHub Actions et par des tests fonctionnels sur Preview.
