# KLICK — application de livraison

KLICK est une application web React/TanStack Start avec Supabase pour les données et l'authentification. Le périmètre de test initial reste Kinshasa, RDC; les paiements Mobile Money ne sont pas intégrés par API et restent confirmés manuellement.

## Développement local

Prérequis : Node.js 22+ et Bun (le dépôt utilise `bun.lock`).

```bash
cp .env.example .env
# Remplir les quatre variables Supabase avec les valeurs du projet de test
bun install --frozen-lockfile
bun run dev
```

## Contrôles

```bash
bun run typecheck
bun run build
bun run lint
```

## Déploiement et migrations

Lire impérativement [`docs/DEPLOYMENT_GITHUB_VERCEL_SUPABASE.md`](docs/DEPLOYMENT_GITHUB_VERCEL_SUPABASE.md) avant d'importer sur GitHub/Vercel ou de pousser des migrations Supabase. Utilisez un projet Supabase de staging pour les tests et ne commitez jamais `.env` ni une clé service role.
