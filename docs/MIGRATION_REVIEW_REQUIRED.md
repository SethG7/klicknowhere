# Revue des migrations avant exécution

Les migrations issues des différents lots ont été regroupées et la collision de version du lot 14/15 a été résolue en donnant à la migration partenaires la version `20261014000510`.

Les migrations n’ont pas été exécutées contre Supabase distant. Avant tout `db push`, vérifiez la base de staging et l’historique de migrations.

Collisions restantes détectées : aucune.

Le build, OAuth et les tests fonctionnels doivent être validés dans GitHub Actions/Vercel Preview.
