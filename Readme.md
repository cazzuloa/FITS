# File Integrity & Tracking System


![License](https://img.shields.io/badge/License-MIT-green.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/cazzuloa/fits)
![GitHub repo size](https://img.shields.io/github/repo-size/cazzuloa/fits)


Petit projet en C++ qui vise à monitorer les fichiers modifiés à l'aide de leurs hashes.

L'idée derrière ce projet est de mieux maîtriser le C++ et de créer un outil que je pourrai réutiliser dans d'autres projets.

## Comment utiliser : 

Avec g++ compiler :

```bash
g++ -std=c++17 -Wall -Wextra src/main.cpp -o fits && ./fits
```

## Stockage des données :

Voir [#1](https://github.com/cazzuloa/FITS/issues/1), l'idée stocker les fichiers présent dans le dossier que l'outils va vérifier, puis en suite stocker les donnés.

Schema des informations stocker: 

```json
{
  "createdAt": "2026-10-31T18:49:19+01:00",
  "folder": "tests",
  "hashAlgorithm": "SHA-256",
  "files": [
    {
      "path": "a.txt",
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "sizeBytes": 0
    }
  ]
}
```

## Changelog

Pour l'historique des versions voir Changelog.md