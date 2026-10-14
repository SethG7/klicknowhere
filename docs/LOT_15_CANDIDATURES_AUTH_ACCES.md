# KLICK — LOT 15 : candidatures initiales, accès privés et Super Admin

## Parcours public/professionnel
- Le client peut continuer à créer son compte par e-mail/mot de passe ou Google (OAuth Google dépend de la configuration Supabase/Lovable et des URL de redirection autorisées).
- Le formulaire de candidature demande les renseignements initiaux, sans imposer un KYC complet au premier contact.
- L'adresse e-mail de contact est facultative dans le formulaire ; le compte doit toutefois être connecté pour relier sûrement la candidature à son auteur.
- Le lien vers la candidature reste visible comme appel à candidater. Le lien vers l'espace professionnel est retiré de la navigation publique et du pied de page.
- La page de connexion professionnelle ne propose plus l'auto-inscription. L'équipe KLICK doit inviter/activer les comptes après approbation.

## Informations demandées
Restaurant : ville, nom, téléphone, e-mail facultatif, domicile du demandeur, adresse de l'établissement, ancienneté facultative et présentation initiale.
Livreur : ville, nom, téléphone, e-mail facultatif, adresse du domicile, individuel ou entreprise, moyen de livraison et ancienneté facultative. Pour une entreprise, nom et adresse de l'entreprise sont requis.

## Super Administrateurs
La migration autorise exclusivement `nkolaguni@gmail.com` et `giuninkola99@gmail.com`, lorsque Supabase confirme l'adresse. Elle promeut les profils existants confirmés et configure un trigger pour les futurs profils. Elle ne peut pas créer un compte Auth à la place de l'utilisateur, envoyer une invitation, ni configurer Google OAuth : ces opérations nécessitent l'accès au projet Supabase et la configuration de l'environnement.

## Installation
1. Fusionner les fichiers dans le dépôt KLICK existant en gardant leurs chemins.
2. Appliquer la migration sur staging après inspection du schéma live.
3. Vérifier que les tables et politiques RLS autorisent les utilisateurs authentifiés à insérer uniquement leurs propres candidatures et que les utilisateurs ne peuvent pas lire celles d'autres personnes.
4. Régénérer `src/integrations/supabase/types.ts` à partir du schéma Supabase réel après migration.
5. Configurer Google dans Authentication > Providers et les URL de redirection (URL locale, preview et domaine de production exacts).
6. Tester avec les deux e-mails après confirmation, puis tester un compte ordinaire pour vérifier qu'il ne peut pas obtenir `super_admin`.
7. Tester candidature restaurant, livreur indépendant, entreprise de livraison, validations et refus.

## Limites à valider
- Le projet source n'a pas été connecté à une instance Supabase distante pendant la préparation de ce patch.
- La migration utilise des contraintes `NOT VALID` pour ne pas bloquer les anciennes lignes ; les nouvelles lignes sont contraintes, mais les anciennes doivent être nettoyées puis les contraintes validées lors d'un lot de données dédié.
- Le build et les tests ne sont pas déclarés réussis tant qu'ils ne sont pas exécutés dans le dépôt avec les dépendances et variables d'environnement réelles.
