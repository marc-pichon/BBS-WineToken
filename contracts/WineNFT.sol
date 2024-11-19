// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WineNFT is ERC721URIStorage, Ownable {

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
        string name;
        uint256[] bottleIds; // Liste des IDs des bouteilles dans la cave
    }

    // Mappings pour stocker les bouteilles et les caves
    mapping(uint256 => Bottle) public bottles;
    mapping(uint256 => Cellar) public cellars;

    // Événements
    event BottleMinted(uint256 bottleId, address owner);
    event CellarMinted(uint256 cellarId, address owner);
    event BottleAddedToCellar(uint256 cellarId, uint256 bottleId);

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
    function mintCellar(string memory name) public onlyOwner returns (uint256) {
        uint256 cellarId = nextCellarId++;
        cellars[cellarId] = Cellar({
            name: name,
            bottleIds: new uint256     });

        _mint(msg.sender, cellarId);
        emit CellarMinted(cellarId, msg.sender);
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

    // Fonction pour obtenir les bouteilles dans une cave
    function getBottlesInCellar(uint256 cellarId) public view returns (Bottle[] memory) {
        uint256[] memory bottleIds = cellars[cellarId].bottleIds;
        Bottle[] memory bottleList = new Bottle[](bottleIds.length);

        for (uint256 i = 0; i < bottleIds.length; i++) {
            bottleList[i] = bottles[bottleIds[i]];
        }
        return bottleList;
    }
}
