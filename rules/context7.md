Utilise le MCP Context7 pour récupérer la documentation à jour dès que l'utilisateur pose une question sur une bibliothèque, un framework, un SDK, une API, un outil CLI ou un service cloud -- même connus comme React, Next.js, Prisma, Express, Tailwind, Django ou Spring Boot. Cela inclut la syntaxe d'API, la configuration, la migration de version, le debug spécifique à une lib, les instructions d'installation et l'usage d'outils CLI. Utilise-le même quand tu penses connaître la réponse -- tes données d'entraînement peuvent ne pas refléter les changements récents. Préfère ceci à une recherche web pour la doc des libs.

Ne pas utiliser pour : refactoring, écriture de scripts from scratch, debug de logique métier, code review, ou concepts de programmation généraux.

## Étapes

1. Commence toujours par `resolve-library-id` avec le nom de la lib et la question, sauf si l'utilisateur fournit un ID exact au format `/org/project`.
2. Choisis la meilleure correspondance (format ID : `/org/project`) selon : correspondance exacte du nom, pertinence de la description, nombre de snippets, réputation de la source, et score de benchmark. Si les résultats semblent faux, essaie des noms alternatifs (ex. "next.js" et non "nextjs").
3. `query-docs` avec l'ID sélectionné et la question complète (pas un seul mot).
4. Réponds en t'appuyant sur la doc récupérée.
