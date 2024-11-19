# BBS-WineToken / repository of backend Solidity smart contract
BBS access repo for wine token project

repository of front and backend Dapp
repository of backend Solidity smart contract
architecture design  documentation



Explication des fonctionnalités :
-------------------------------

smart contract en Solidity qui implémente le concept, en utilisant les composite NFTs (ERC-721) pour représenter les caves et les bouteilles. Chaque bouteille est associée à un NFT, et une cave (également un NFT) peut contenir plusieurs bouteilles.


Représentation des bouteilles :
-----------------------------

Chaque bouteille est un NFT unique (ERC-721).
Les informations spécifiques sont enregistrées dans la structure Bottle. 
(Leur millésime (année du vin)
•	Leur format
•	L’état des étiquettes
•	L’état des bouchons/capsules
•	Le niveau des vins
•	Leur photo)

Chaque bouteille possède un photoURI, un lien vers une image ou des métadonnées associées.
Représentation des caves :

Une cave est également un NFT unique, représenté par un Cellar.
Elle contient un tableau d'IDs de bouteilles, permettant de gérer dynamiquement les contenus de la cave.
Ajout dynamique :

Les bouteilles peuvent être ajoutées à une cave via la fonction addBottleToCellar.
Consultation des caves :

La fonction getBottlesInCellar permet d'obtenir les détails de toutes les bouteilles contenues dans une cave.
Séparation des IDs :

Les IDs des bouteilles commencent à 1.
Les IDs des caves commencent à 10 001 pour éviter les collisions.





Modèle financier intégré :
------------------------

La fonction calculateBottleValue utilise l'âge de la bouteille pour déterminer sa valeur actuelle selon la courbe de maturité.
Avant la maturité (âge optimal), la valeur suit une croissance linéaire (simplification de la logistique).
Après la maturité, la valeur diminue selon un taux de déclin.
Protection des cas limites :

Si l'âge est négatif (bouteille créée dans le futur), la valeur est nulle.
Après une forte détérioration (âge très avancé), la valeur devient également nulle.
Données dynamiques :

Les calculs utilisent l'année actuelle (currentYear), dérivée de block.timestamp.

