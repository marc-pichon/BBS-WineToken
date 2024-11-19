// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// Importation pour gérer les signatures
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/*
Structure hiérarchique : Les caves et les bouteilles sont organisées de manière logique avec les mappings bottles et cellars
Compatibilité avec les standards ERC-721 : 
Les transferts et la destruction des NFTs utilisent des fonctions standards (_transfer, _burn) pour assurer la conformité.
*/
contract WineNFT is ERC721URIStorage, Ownable {
    using ECDSA for bytes32;

    uint256 public nextBottleId = 1;
    uint256 public nextCellarId = 10001;

    struct Bottle {
        string domain;
        uint16 vintage; // Année du vin
        string format; // e.g., "750ml", "1.5L"
        string labelCondition; // État des étiquettes
        string corkCondition; // État des bouchons/capsules
        string wineLevel; // Niveau du vin
        string photoURI; // URI vers la photo de la bouteille
        uint256 maxValue; // Vmax : Valeur maximale à maturité
        uint16 optimalAge; // t_opt : Âge optimal (en années)
        uint16 mintYear; // Année de mint du NFT
    }

    struct Cellar {
        string cellarname; // nom de la cave - donné par le particulier
        uint256 cellarId; // Identifiant unique de la cave
        address cellarCustomerAddress; // Adresse de wallet du propriétaire
        string cellarLocation; // Adresse physique de la cave
        uint256 cellarReputation; // Score de réputation de la cave
        uint256[] bottleIds; // Liste des bouteilles dans la cave
    }

    // Mappings pour stocker les bouteilles et les caves
    mapping(uint256 => Bottle) public bottles;
    mapping(uint256 => Cellar) public cellars;

    // Événements
    event BottleMinted(uint256 bottleId, address owner);
    event CellarMinted(uint256 cellarId, address owner);
    event BottleAddedToCellar(uint256 cellarId, uint256 bottleId);
    event BottlesSwapped(address indexed userA, address indexed userB, uint256[] bottlesA, uint256[] bottlesB);


   constructor("argument_a_trouver") ERC721("WineNFT", "WIN") {}
    

    // Fonction pour minter un NFT représentant une bouteille
    function mintBottle(
        string memory domain,
        uint16 vintage,
        string memory format,
        string memory labelCondition,
        string memory corkCondition,
        string memory wineLevel,
        string memory photoURI,
        uint256 maxValue, // Vmax
        uint16 optimalAge // t_opt
    ) public onlyOwner returns (uint256) {
        uint256 bottleId = nextBottleId++;
        bottles[bottleId] = Bottle({
            domain: domain,
            vintage: vintage,
            format: format,
            labelCondition: labelCondition,
            corkCondition: corkCondition,
            wineLevel: wineLevel,
            photoURI: photoURI,
            maxValue: maxValue,
            optimalAge: optimalAge,
            mintYear: uint16(block.timestamp / 365 days + 1970) // Année approximative actuelle
        });

        _mint(msg.sender, bottleId);
        _setTokenURI(bottleId, photoURI);

        emit BottleMinted(bottleId, msg.sender);
        return bottleId;
    }

    // Fonction pour minter un NFT représentant une cave
    function mintCellar(
        address to,
        string name, 
        string memory location, 
        uint256 reputation
    ) external onlyOwner returns (uint256) {
        // Générer un nouvel identifiant unique pour la cave
        uint256 cellarId = nextCellarId++;
        
        // Enregistrer la cave dans le mapping
        cellars[cellarId] = Cellar({
            cellarId: cellarId,
            cellarname: name;
            cellarCustomerAddress: to,
            cellarLocation: location,
            cellarReputation: reputation,
            bottleIds: new uint256Initialise la liste vide des bouteilles
        });

        // Mint du NFT pour représenter cette cave
        _safeMint(to, cellarId);
        emit CellarMinted(cellarId, msg.sender);
        // Retourne l'identifiant de la cave
        return cellarId;
    }

    // Fonction pour ajouter une bouteille dans une cave
    function addBottleToCellar(uint256 cellarId, uint256 bottleId) public onlyOwner {
        require(ownerOf(cellarId) == msg.sender, "Vous ne possedez pas cette cave");
        require(ownerOf(bottleId) == msg.sender, "Vous ne possedez pas cette bouteille");

        cellars[cellarId].bottleIds.push(bottleId);
        emit BottleAddedToCellar(cellarId, bottleId);
    }

    // Fonction pour calculer la valeur actuelle d'une bouteille
    function calculateBottleValue(uint256 bottleId) public view returns (uint256) {
        Bottle memory bottle = bottles[bottleId];
        uint16 currentYear = uint16(block.timestamp / 365 days + 1970); // Année actuelle approximative
        uint16 age = currentYear - bottle.vintage;

        if (age <= 0) {
            return 0; // Valeur nulle si le vin n'a pas encore vieilli
        }

        if (age <= bottle.optimalAge) {
            // Croissance logistique avant maturité
            uint256 value = (bottle.maxValue * age) / bottle.optimalAge;
            return value;
        } else {
            // Déclin après maturité
            uint256 declineRate = (bottle.maxValue * (age - bottle.optimalAge)) / (2 * bottle.optimalAge);
            if (bottle.maxValue > declineRate) {
                return bottle.maxValue - declineRate;
            } else {
                return 0; // Valeur minimale nulle
            }
        }
    }
      /* 
      Fonction pour calculer la valeur d'une bouteille en  fonction de criteres supplémentaires
            labelCondition
            corkCondition (etat bouchaon)
            cellarReputation
     */       
 
    function calculateBottleStateValue(uint256 bottleId, uint256 cellarReputation) public view returns (uint256) {
        Bottle memory bottle = bottles[bottleId];
     
        uint256 conditionFactor = 1;

        if (keccak256(bytes(bottle.corkCondition)) == keccak256(bytes("excellent"))) {
            conditionFactor += 1;
        }
        if (keccak256(bytes(bottle.labelCondition)) == keccak256(bytes("perfect"))) {
            conditionFactor += 1;
        }
        if (keccak256(bytes(cellarReputation)) == 1) {
            conditionFactor += 1;
        }

        return conditionFactor;
    }
// ----------------------------------------
    // Calculer la valeur totale d'une cave
    // ----------------------------------------
    function calculateCellarValue(uint256 cellarId) public view returns (uint256) {
        require(_exists(cellarId), "Cellar does not exist");

        Cellar memory cellar = cellars[cellarId];
        uint256 totalValue = 0;

        for (uint256 i = 0; i < cellar.bottleIds.length; i++) {
            uint256 bottleId = cellar.bottleIds[i];
            totalValue += calculateBottleValue(bottleId);
        }

        return totalValue;
    }
    // Fonction pour obtenir les bouteilles dans une cave
    function getBottlesInCellar(uint256 cellarId) public view returns (Bottle[] memory) {
        uint256[] memory bottleIds = cellars[cellarId].bottleIds;
        Bottle[] memory bottleList = new Bottle[](bottleIds.length);

        for (uint256 i = 0; i < bottleIds.length; i++) {
            bottleList[i] = bottles[bottleIds[i]];
        }
        return bottleList;
    }
    // ----------------------------------------
    // Transfert d'un NFT bouteille
    // ----------------------------------------

    // Propriétaire d'une cave : La cave est représentée par un NFT. 
    // Seul le détenteur de ce NFT peut effectuer des actions comme ajouter une bouteille ou détruire la cave.
    function transferBottle(uint256 bottleId, address from, address to) external {
        require(bottles[bottleId].millesime > 0, "Bottle does not exist");
        require(ownerOf(bottleId) == from, "You do not own this bottle");
        _transfer(from, to, bottleId);
    }
    // ----------------------------------------
    // Transfert d'un NFT cave
    // ----------------------------------------
    // transferCellar : La propriété cellarCustomerAddress dans le mapping est mise à jour lors d'un transfert.
    
    function transferCellar(uint256 cellarId, address from, address to) external {
        require(_exists(cellarId), "Cellar does not exist");
        require(ownerOf(cellarId) == from, "You do not own this cellar");

        // Mise à jour du propriétaire dans le mapping
        cellars[cellarId].cellarCustomerAddress = to;

        // Transfert du NFT
        _transfer(from, to, cellarId);
    }
    // ----------------------------------------
    // Burn d'un NFT bouteille
    // ----------------------------------------
    function burnBottle(uint256 bottleId) external {
        require(bottles[bottleId].millesime > 0, "Bottle does not exist");
        require(ownerOf(bottleId) == msg.sender, "You do not own this bottle");

        // Supprimer la bouteille du mapping
        delete bottles[bottleId];

        // Burn le NFT
        _burn(bottleId);
    }
    // ----------------------------------------
    // Burn d'un NFT cave
    // ----------------------------------------
    function burnCellar(uint256 cellarId) external {
        require(_exists(cellarId), "Cellar does not exist");
        require(ownerOf(cellarId) == msg.sender, "You do not own this cellar");

        // Supprimer toutes les bouteilles liées à cette cave
        uint256[] memory bottleIds = cellars[cellarId].bottleIds;
        for (uint256 i = 0; i < bottleIds.length; i++) {
            delete bottles[bottleIds[i]];
            _burn(bottleIds[i]);
        }

        // Supprimer la cave du mapping
        delete cellars[cellarId];

        // Burn le NFT de la cave
        _burn(cellarId);
    }
        /// Fonction pour effectuer un échange entre particuliers
        /*
        Vérification des propriétés :

Les bouteilles du lot A doivent appartenir à l'utilisateur A.
Les bouteilles du lot B doivent appartenir à l'utilisateur B.
Calcul des valeurs des lots :

La fonction calculateBottleValue est utilisée pour calculer la valeur de chaque bouteille.
Les valeurs des bouteilles sont additionnées pour obtenir la valeur totale de chaque lot.
Tolérance de 10 % :

La condition totalValueA >= (totalValueB * 90) / 100 && totalValueA <= (totalValueB * 110) / 100 garantit que la différence de valeur entre les lots est dans une fourchette de ±10 %.
Transfert des lots :

Les bouteilles sont retirées des listes des propriétaires initiaux et ajoutées aux listes des nouveaux propriétaires.
La propriété des NFTs est transférée dans le mapping bottleOwners.
Événement :

L’événement BottlesSwapped enregistre l’échange sur la blockchain.

Signature numérique :
Avant d'exécuter l'échange, le contrat vérifie que l’utilisateur B a signé l’accord. La signature garantit qu’il est au courant de l’échange et accepte ses conditions.
Utilisation de la librairie ECDSA :
messageHash.toEthSignedMessageHash() génère un hash compatible avec Ethereum pour validation.
recover(signature) récupère l’adresse du signataire.


comment a l'interface UI proposer les echanges? complexe.
*/

// remplir ces 2 tableaux
    mapping(uint256 => address) public bottleOwners; // les bouteiiles de A et  B
    mapping(address => uint256[]) public ownerBottles // les user A   et B

 // Structure d'une proposition d'échange
    struct SwapProposal {
        uint256[] bottlesA;
        uint256[] bottlesB;
        address userA;
        address userB;
    }
    // Fonction pour vérifier la signature d'une proposition d'échange
    function _verifySwapProposal(
        SwapProposal memory proposal,
        bytes memory signature
    ) internal pure returns (bool) {
        // Recréer le message signé
        bytes32 messageHash = keccak256(
            abi.encodePacked(proposal.bottlesA, proposal.bottlesB, proposal.userA, proposal.userB)
        );
        // Récupérer le signataire
        address signer = messageHash.toEthSignedMessageHash().recover(signature);
        return signer == proposal.userB; // Vérifie que l'utilisateur B a signé
    }
    function swapBottles(
    uint256[] memory bottlesA,
    uint256[] memory bottlesB,
    address userB, // Ajout explicite de l’adresse de B
    bytes memory signature
) external {
    address userA = msg.sender;
    address userB = bottleOwners[bottlesB[0]];

    // Vérifier la signature de l'utilisateur B
    SwapProposal memory proposal = SwapProposal({
        bottlesA: bottlesA,
        bottlesB: bottlesB,
        userA: userA,
        userB: userB
    });
    require(_verifySwapProposal(proposal, signature), "Signature invalide ou absente");

    // Vérifications des propriétés
    for (uint256 i = 0; i < bottlesA.length; i++) {
        require(bottleOwners[bottlesA[i]] == userA, "Utilisateur A ne possède pas toutes les bouteilles");
    }
    for (uint256 i = 0; i < bottlesB.length; i++) {
        require(bottleOwners[bottlesB[i]] == userB, "Utilisateur B ne possède pas toutes les bouteilles");
    }

    // Calcul des valeurs et validation de la fourchette de 10 %
    uint256 totalValueA = 0;
    uint256 totalValueB = 0;
    for (uint256 i = 0; i < bottlesA.length; i++) totalValueA += calculateBottleValue(bottlesA[i]);
    for (uint256 i = 0; i < bottlesB.length; i++) totalValueB += calculateBottleValue(bottlesB[i]);

    require(
        totalValueA >= (totalValueB * 90) / 100 && totalValueA <= (totalValueB * 110) / 100,
        "Différence de valeur hors limites"
    );

    // Effectuer l'échange
    for (uint256 i = 0; i < bottlesA.length; i++) {
        bottleOwners[bottlesA[i]] = userB;
        ownerBottles[userB].push(bottlesA[i]);
        _removeBottleFromOwner(userA, bottlesA[i]);
    }
    for (uint256 i = 0; i < bottlesB.length; i++) {
        bottleOwners[bottlesB[i]] = userA;
        ownerBottles[userA].push(bottlesB[i]);
        _removeBottleFromOwner(userB, bottlesB[i]);
    }

    emit BottlesSwapped(userA, userB, bottlesA, bottlesB, block.timestamp);
}


    /// Fonction privée pour retirer une bouteille de la liste d'un utilisateur
    function _removeBottleFromOwner(address owner, uint256 bottleId) private {
        uint256[] storage bottlesList = ownerBottles[owner];
        for (uint256 i = 0; i < bottlesList.length; i++) {
            if (bottlesList[i] == bottleId) {
                bottlesList[i] = bottlesList[bottlesList.length - 1];
                bottlesList.pop();
                break;
            }
        }
    }
   
}
