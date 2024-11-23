// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/// integration de la gestion d'un token d'achat du NFT par mint
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/// Importation pour gerer les signatures
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title Tokenisation cave et bouteilles associees
/** 
Structure hierarchique : Les caves et les bouteilles sont organisees de maniere logique avec les mappings bottles et cellars
Compatibilite avec les standards ERC-721 : 
Les transferts et la destruction des NFTs utilisent des fonctions standards (_transfer, _burn) pour assurer la conformite.
*/
contract WineNFT is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    constructor(
        address initialOwner
    ) ERC721("WineNFT", "WIN") Ownable(initialOwner) {}

    using ECDSA for bytes32;

    uint256 public nextBottleId = 1;
    uint256 public nextCellarId = 10001;

    struct Bottle {
        string domain;
        uint16 vintage; /// Annee du vin
        string format; /// e.g., "750ml", "1.5L"
        string labelCondition; /// etat des etiquettes
        string corkCondition; /// etat des bouchons/capsules
        string wineLevel; /// Niveau du vin
        string photoURI; /// URI vers la photo de la bouteille
        uint256 maxValue; /// Vmax : Valeur maximale a maturite
        uint16 optimalAge; /// t_opt : Âge optimal (en annees)
        uint16 mintYear; /// Annee de mint du NFT
    }

    struct Cellar {
        string cellarname; /// nom de la cave - donne par le particulier
        uint256 cellarId; /// Identifiant unique de la cave
        address cellarCustomerAddress; /// Adresse de wallet du proprietaire
        string cellarLocation; /// Adresse physique de la cave
        uint256 cellarReputation; /// Score de reputation de la cave
        uint256[] bottleIds; /// Liste des bouteilles dans la cave
    }

    /// Mappings pour stocker les bouteilles et les caves
    mapping(uint256 => Bottle) public bottles;
    mapping(uint256 => Cellar) public cellars;

    /// integration d'un token ERC20 achat/vente
    IERC20 public paymentToken; // Token ERC20 utilisé pour le paiement
    uint256 public mintPrice; // Prix en token ERC20 pour mint un NFT

    /// evenements
    event BottleMinted(uint256 bottleId, address owner);
    event CellarMinted(uint256 cellarId, address owner);
    event BottleAddedToCellar(uint256 cellarId, uint256 bottleId);
    event BottlesSwapped(
        address indexed userA,
        address indexed userB,
        uint256[] bottlesA,
        uint256[] bottlesB,
        uint256 blockTimestamp
    );
    // Event pour le mint
    event BottleMSoldUsingToken(
        address indexed owner,
        address to,
        uint256 tokenId,
        uint256 price
    );

    /// tokenURI = _baseURI + tokenID
    function _baseURI() internal pure override returns (string memory) {
        return "https://bbswinenft.io";
    }

    /// Fonction pour minter un NFT representant une bouteille
    /// @param domain the domain
    /// @param  vintage millesime
    /// @param  format standard, magnum, half
    /// @param  labelCondition excellent, medium, bad
    /// @param  corkCondition excellent, medium, bad
    /// @param  wineLevel excellent, medium, bad
    /// @param  photoURI URI
    /// @param maxValue Vmax
    /// @param  optimalAge t_opt
    /// @return bottleId Id bottle

    function mintBottle(
        string memory domain,
        uint16 vintage,
        string memory format,
        string memory labelCondition,
        string memory corkCondition,
        string memory wineLevel,
        string memory photoURI,
        uint256 maxValue, /// Vmax
        uint16 optimalAge /// t_opt
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
            mintYear: uint16(block.timestamp / 365 days + 1970) /// Annee approximative actuelle
        });

        _mint(msg.sender, bottleId);
        _setTokenURI(bottleId, photoURI);

        emit BottleMinted(bottleId, msg.sender);
        return bottleId;
    }

    /// Fonction pour minter un NFT representant une cave
    function mintCellar(
        address to,
        string memory name,
        string memory location,
        uint256 reputation
    ) external onlyOwner returns (uint256) {
        /// Generer un nouvel identifiant unique pour la cave
        uint256 cellarId = nextCellarId++;

        /// Enregistrer la cave dans le mapping
        cellars[cellarId] = Cellar({
            cellarId: cellarId,
            cellarname: name,
            cellarCustomerAddress: to,
            cellarLocation: location,
            cellarReputation: reputation,
            bottleIds: new uint256[](0) /// Initialise la liste vide des bouteilles
        });

        /// Mint du NFT pour representer cette cave
        _safeMint(to, cellarId);
        emit CellarMinted(cellarId, msg.sender);
        /// Retourne l'identifiant de la cave
        return cellarId;
    }

    /// Fonction pour ajouter une bouteille dans une cave
    function addBottleToCellar(
        uint256 cellarId,
        uint256 bottleId
    ) public onlyOwner {
        require(
            ownerOf(cellarId) == msg.sender,
            "Vous ne possedez pas cette cave"
        );
        require(
            ownerOf(bottleId) == msg.sender,
            "Vous ne possedez pas cette bouteille"
        );

        cellars[cellarId].bottleIds.push(bottleId);
        emit BottleAddedToCellar(cellarId, bottleId);
    }

    /// Fonction pour calculer la valeur actuelle d'une bouteille
    function calculateBottleValue(
        uint256 bottleId
    ) public view returns (uint256) {
        Bottle memory bottle = bottles[bottleId];
        uint16 currentYear = uint16(block.timestamp / 365 days + 1970); /// Annee actuelle approximative
        uint16 age = currentYear - bottle.vintage;

        if (age <= 0) {
            return 0; /// Valeur nulle si le vin n'a pas encore vieilli
        }

        if (age <= bottle.optimalAge) {
            /// Croissance logistique avant maturite
            uint256 value = (bottle.maxValue * age) / bottle.optimalAge;
            return value;
        } else {
            /// Declin apres maturite
            uint256 declineRate = (bottle.maxValue *
                (age - bottle.optimalAge)) / (2 * bottle.optimalAge);
            if (bottle.maxValue > declineRate) {
                return bottle.maxValue - declineRate;
            } else {
                return 0; /// Valeur minimale nulle
            }
        }
    }

    /**
      Fonction pour calculer la valeur d'une bouteille en  fonction de criteres supplementaires
            labelCondition
            corkCondition (etat bouchaon)
            cellarReputation
     */

    function calculateBottleStateValue(
        uint256 bottleId,
        uint256 cellarReputation
    ) public view returns (uint256) {
        Bottle memory bottle = bottles[bottleId];

        uint256 conditionFactor = 1;

        if (
            keccak256(bytes(bottle.corkCondition)) ==
            keccak256(bytes("excellent"))
        ) {
            conditionFactor += 1;
        }
        if (
            keccak256(bytes(bottle.labelCondition)) ==
            keccak256(bytes("perfect"))
        ) {
            conditionFactor += 1;
        }
        if (cellarReputation == 1) {
            conditionFactor += 1;
        }

        return conditionFactor;
    }

    /// ----------------------------------------
    /// Calculer la valeur totale d'une cave
    /// ----------------------------------------
    function calculateCellarValue(
        uint256 cellarId
    ) public view returns (uint256) {
        /// _exists not recognized with require(_exists(cellarId), "Cellar does not exist");
        require(ownerOf(cellarId) != address(0), "Cellar does not exist");

        Cellar memory cellar = cellars[cellarId];
        uint256 totalValue = 0;

        for (uint256 i = 0; i < cellar.bottleIds.length; i++) {
            uint256 bottleId = cellar.bottleIds[i];
            totalValue += calculateBottleValue(bottleId);
        }

        return totalValue;
    }

    /// Fonction pour obtenir les bouteilles dans une cave
    function getBottlesInCellar(
        uint256 cellarId
    ) public view returns (Bottle[] memory) {
        uint256[] memory bottleIds = cellars[cellarId].bottleIds;
        Bottle[] memory bottleList = new Bottle[](bottleIds.length);

        for (uint256 i = 0; i < bottleIds.length; i++) {
            bottleList[i] = bottles[bottleIds[i]];
        }
        return bottleList;
    }

    /// ----------------------------------------
    /// Transfert d'un NFT bouteille
    /// ----------------------------------------

    /// Proprietaire d'une cave : La cave est representee par un NFT.
    /// Seul le detenteur de ce NFT peut effectuer des actions comme ajouter une bouteille ou detruire la cave.
    function transferBottle(
        uint256 bottleId,
        address from,
        address to
    ) public payable {
        require(bottleId > 0, "Bottle does not exist");
        require(ownerOf(bottleId) == from, "You do not own this bottle");
        _transfer(from, to, bottleId);
    }

    /// ----------------------------------------
    /// Transfert d'un NFT cave
    /// ----------------------------------------
    /// transferCellar : La propriete cellarCustomerAddress dans le mapping est mise a jour lors d'un transfert.

    function transferCellar(
        uint256 cellarId,
        address from,
        address to
    ) external {
        /// _exists not recognized with require(_exists(cellarId), "Cellar does not exist");
        require(ownerOf(cellarId) != address(0), "Cellar does not exist");
        require(ownerOf(cellarId) == from, "You do not own this cellar");

        /// Mise a jour du proprietaire dans le mapping
        cellars[cellarId].cellarCustomerAddress = to;

        /// Transfert du NFT
        _transfer(from, to, cellarId);
    }

    /// ----------------------------------------
    /// Burn d'un NFT bouteille
    /// ----------------------------------------
    function burnBottle(uint256 bottleId) external {
        require(bottleId > 0, "Bottle does not exist");
        require(ownerOf(bottleId) == msg.sender, "You do not own this bottle");

        /// Supprimer la bouteille du mapping
        delete bottles[bottleId];

        /// Burn le NFT
        _burn(bottleId);
    }

    /// ----------------------------------------
    /// Burn d'un NFT cave
    /// ----------------------------------------
    function burnCellar(uint256 cellarId) external {
        /// _exists not recognized with require(_exists(cellarId), "Cellar does not exist");
        require(ownerOf(cellarId) != address(0), "Cellar does not exist");
        require(ownerOf(cellarId) == msg.sender, "You do not own this cellar");

        /// Supprimer toutes les bouteilles liees a cette cave
        uint256[] memory bottleIds = cellars[cellarId].bottleIds;
        for (uint256 i = 0; i < bottleIds.length; i++) {
            delete bottles[bottleIds[i]];
            _burn(bottleIds[i]);
        }

        /// Supprimer la cave du mapping
        delete cellars[cellarId];

        /// Burn le NFT de la cave
        _burn(cellarId);
    }

    /// Fonction pour effectuer un echange entre particuliers
    /** 
        Verification des proprietes :

Les bouteilles du lot A doivent appartenir a l'utilisateur A.
Les bouteilles du lot B doivent appartenir a l'utilisateur B.
Calcul des valeurs des lots :

La fonction calculateBottleValue est utilisee pour calculer la valeur de chaque bouteille.
Les valeurs des bouteilles sont additionnees pour obtenir la valeur totale de chaque lot.
Tolerance de 10 % :

La condition totalValueA >= (totalValueB * 90) / 100 && totalValueA <= (totalValueB * 110) / 100 garantit que la difference de valeur entre les lots est dans une fourchette de ±10 %.
Transfert des lots :

Les bouteilles sont retirees des listes des proprietaires initiaux et ajoutees aux listes des nouveaux proprietaires.
La propriete des NFTs est transferee dans le mapping bottleOwners.
evenement :

L’evenement BottlesSwapped enregistre l’echange sur la blockchain.

Signature numerique :
Avant d'executer l'echange, le contrat verifie que l’utilisateur B a signe l’accord. La signature garantit qu’il est au courant de l’echange et accepte ses conditions.
Utilisation de la librairie ECDSA :
messageHash.toEthSignedMessageHash() genere un hash compatible avec Ethereum pour validation.
recover(signature) recupere l’adresse du signataire.


comment a l'interface UI proposer les echanges? complexe.
*/

    /// remplir ces 2 tableaux
    mapping(uint256 => address) public bottleOwners; /// les bouteiiles de A et  B
    mapping(address => uint256[]) public ownerBottles; /// les user A   et B

    /// Structure d'une proposition d'echange
    struct SwapProposal {
        uint256[] bottlesA;
        uint256[] bottlesB;
        address userA;
        address userB;
    }

    /// Fonction pour verifier la signature d'une proposition d'echange
    function _verifySwapProposal(
        SwapProposal memory proposal,
        /// address signer,
        bytes memory signature
    ) private pure returns (bool) {
        /// Recreer le message signe
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                proposal.bottlesA,
                proposal.bottlesB,
                proposal.userA,
                proposal.userB
            )
        );
        ///  a revoir completement!!!
        /// Add the standard Ethereum signature prefix using OpenZeppelin's function
        //bytes32 prefixedMessage = ECDSA.toEthSignedMessageHash(messageHash);
        //address recoveredSigner = ECDSA.recover(prefixedMessage, signature);
        //return signer == proposal.userB; /// Verifie que l'utilisateur B a signe
        return true;
    }

    function swapBottles(
        uint256[] memory bottlesA,
        uint256[] memory bottlesB,
        address userB, /// Ajout explicite de l’adresse de B
        bytes memory signature
    ) external {
        address userA = msg.sender;
        address userB = bottleOwners[bottlesB[0]];

        /// Verifier la signature de l'utilisateur B
        SwapProposal memory proposal = SwapProposal({
            bottlesA: bottlesA,
            bottlesB: bottlesB,
            userA: userA,
            userB: userB
        });
        require(
            _verifySwapProposal(proposal, signature),
            "Signature invalide ou absente"
        );

        /// Verifications des proprietes
        for (uint256 i = 0; i < bottlesA.length; i++) {
            require(
                bottleOwners[bottlesA[i]] == userA,
                "Utilisateur A ne possede pas toutes les bouteilles"
            );
        }
        for (uint256 i = 0; i < bottlesB.length; i++) {
            require(
                bottleOwners[bottlesB[i]] == userB,
                "Utilisateur B ne possede pas toutes les bouteilles"
            );
        }

        /// Calcul des valeurs et validation de la fourchette de 10 %
        uint256 totalValueA = 0;
        uint256 totalValueB = 0;
        for (uint256 i = 0; i < bottlesA.length; i++)
            totalValueA += calculateBottleValue(bottlesA[i]);
        for (uint256 i = 0; i < bottlesB.length; i++)
            totalValueB += calculateBottleValue(bottlesB[i]);

        require(
            totalValueA >= (totalValueB * 90) / 100 &&
                totalValueA <= (totalValueB * 110) / 100,
            "Difference de valeur hors limites"
        );

        /// Effectuer l'echange
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

    //// Fonction privee pour retirer une bouteille de la liste d'un utilisateur
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

    /// achat d'une bouteille appartenant a un particulier avec un token ERRC20
    function buyBottleUsingToken(
        uint256 bottleId,
        address _paymentToken,
        uint256 _mintPrice
    ) public payable returns (uint256) {
        paymentToken = IERC20(_paymentToken);
        mintPrice = _mintPrice;
        require(
            paymentToken.balanceOf(msg.sender) >= mintPrice,
            "Solde insuffisant"
        );
        require(
            paymentToken.allowance(msg.sender, address(this)) >= mintPrice,
            "Approuvez le transfert de tokens"
        );

        // Transfert des tokens du payeur vers le contrat
        bool success = paymentToken.transferFrom(
            msg.sender,
            address(this),
            mintPrice
        );
        require(success, "Echec du transfert des tokens");

        // Transfert du NFT a l'acheteur
        transferBottle(bottleId, address(this), msg.sender);

        emit BottleMSoldUsingToken(
            msg.sender,
            address(this),
            bottleId,
            mintPrice
        );
        return bottleId;
    }

    /// Fonction pour mettre à jour le token ERC20 utilise
    function setPaymentToken(address _token) external onlyOwner {
        paymentToken = IERC20(_token);
    }

    ///Fonction pour mettre à jour le prix du mint
    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    // Fonction qui permet au propriétaire du contrat de récupérer les tokens ERC20 reçus
    function withdrawTokens() external onlyOwner {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "Aucun token a retirer");

        bool success = paymentToken.transfer(owner(), balance);
        require(success, "Echec du retrait des tokens");
    }

    /// The following functions are overrides required by Solidity.

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
