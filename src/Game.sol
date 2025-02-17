// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Game is ERC1155, Ownable {
    // each weapon damange level is 10 more Rare Links
    enum WeaponDamage {
        NoHarm,
        Low,
        Medium,
        Hard,
        Extreme,
        Unlimited
    }

    // each weapon rarity level is 100 more Rare Links
    enum WeaponRarity {
        Common,
        Uncommon,
        Rare,
        Epic,
        Legendary,
        Unicorn
    }

    // each weapon size is 5 more Rare Links
    enum WeaponSize {
        UltaSmall,
        Small,
        Medium,
        Large,
        UltraLarge
    }

    // each weapon colour is 1 more Rare Links
    enum WeaponColour {
        White,
        Black,
        Brown,
        Yellow,
        Green,
        Red,
        Violet,
        Silver,
        Gold
    }

    struct WeaponTraits {
        bool minted;
        WeaponDamage damage;
        WeaponRarity rarity;
        WeaponSize size;
        WeaponColour colour;
    }

    uint256 private constant RARE_LINK_COLLECTION_ID = 1;
    uint256 private constant WEAPON_COLLECTION_ID = 2;
    uint256 private constant ARTIFACT_COLLECTION_ID = 3;
    string private GAME_URI = "http://game.it";
    uint256 private rareLinkTokenSupply = 10000 * 10 ** 18;
    uint256 private rareLinkValue = 100000;
    uint256 private weaponNextTokenId = 0;
    uint256 private weaponsLimit = 10000;
    uint256 private artifactNextTokenId = 0;
    uint256 private artifactsLimit = 5000;
    uint256 private baseArtifactCost = 1000;
    uint256 private multiplierArtifactCost = 10;
    mapping(address player => bool exists) private players;
    mapping(uint256 weaponTokenId => WeaponTraits traits) weaponsMinted;
    mapping(uint256 artifactTokenId => bytes32 traits) legendaryArtifactsMinted;

    event RareLinksPurchased(address indexed player, uint256 rareLinkAmount);
    event NewPlayerRegistered(address indexed player);
    event WeaponMinted(
        address indexed player, uint256 indexed tokenId, uint8 damage, uint8 rarity, uint8 size, uint8 colour
    );
    event LegendaryArtifactMinted(address indexed player, uint256 indexed tokenId, bytes32 traits);

    constructor() ERC1155(GAME_URI) Ownable(msg.sender) {}

    // useful to set mint limits, total supply, conversion rate for in-game currency etc
    function setConfig(
        uint256 _rareLinkTotalSupply,
        uint256 _rareLinkValue,
        uint256 _weaponsLimit,
        uint256 _artifactsLimit,
        uint256 _baseArtifactCost,
        uint256 _multiplierArtifactCost
    ) external onlyOwner {
        require(rareLinkTokenSupply <= _rareLinkTotalSupply, "new supply can't be lower than old one");
        require(_rareLinkValue > 0, "rare link value must be greater than zero");
        require(
            _weaponsLimit > 0 && weaponsLimit < _weaponsLimit,
            "new weapons limit can't be zero or less than the old limit"
        );
        require(
            _artifactsLimit > 0 && artifactsLimit < _artifactsLimit,
            "new artifacts limit can't be zero or less than the old limit"
        );
        require(_baseArtifactCost > 0, "base artifact cost can't be zero");
        require(_multiplierArtifactCost > 0, "multiplier artifact cost can't be zero");
        rareLinkTokenSupply = _rareLinkTotalSupply;
        rareLinkValue = _rareLinkValue;
        weaponsLimit = _weaponsLimit;
        artifactsLimit = _artifactsLimit;
        baseArtifactCost = _baseArtifactCost;
        multiplierArtifactCost = _multiplierArtifactCost;
    }

    // each player must register first, in the next stage we need to force the user to buy minimum amount of in-game currency (as "registration fee")
    function registerPlayer(uint256 buyRareLinkAmount) external payable {
        require(!players[msg.sender], "player is already registered");

        // player is not forced to buy immediately, but maybe we need to introduce "registration fee"?
        if (buyRareLinkAmount > 0) {
            _purchaseRareLinks(buyRareLinkAmount);
        }

        emit NewPlayerRegistered(msg.sender);
    }

    function buyRareLink(uint256 buyRareLinkAmount) external payable {
        require(players[msg.sender], "address is not a registered player");
        _purchaseRareLinks(buyRareLinkAmount);
    }

    // helper internal function
    function _purchaseRareLinks(uint256 buyRareLinkAmount) internal {
        require(
            buyRareLinkAmount > 0 && buyRareLinkAmount < rareLinkTokenSupply,
            "buy amount must be greater than zero and less than total supply"
        );
        // TODO: this is too strict, how to pay back the user if user sends too much?
        require(msg.value == (buyRareLinkAmount * rareLinkValue), "not enough to buy rare links");

        rareLinkTokenSupply -= buyRareLinkAmount;
        // TODO: probably setting id to RARE_LINK_COLLECTION_ID is enough, but I want to keep it consistent with bit shifting
        _mint(msg.sender, RARE_LINK_COLLECTION_ID << 128, buyRareLinkAmount, "");
        emit RareLinksPurchased(msg.sender, buyRareLinkAmount);
    }

    // player may choose different traits and different "levels" of those traits, but each trait has a different cost
    // player must be ready to pay for minting with in-game currency
    // TODO: do we want to return token ID or is emitting an event enough?
    function mintUniqueWeapon(WeaponDamage damageLevel, WeaponRarity rarityLevel, WeaponColour colour, WeaponSize size)
        external
        payable
    {
        require(players[msg.sender], "address is not a registered player");
        require(weaponNextTokenId < weaponsLimit, "limit of allowed minted unique weapons was reached");
        // each trait has a different cost, also depending on the trait level or difference
        uint256 weaponCost = (uint256(damageLevel) + 1 * 10) + (uint256(rarityLevel) + 1 * 100)
            + (uint256(colour) + 1 * 1) + (uint256(size) + 1 * 5);
        require(
            balanceOf(msg.sender, RARE_LINK_COLLECTION_ID << 128) >= weaponCost,
            "player doesn't have enough rare links to purchase this weapon"
        );

        // before we burn player's rare link token, we will bring them back to the total supply
        rareLinkTokenSupply += weaponCost;
        _burn(msg.sender, RARE_LINK_COLLECTION_ID << 128, weaponCost);

        // keep a list of selected traits in the contract after minting the weapon
        uint256 id = (WEAPON_COLLECTION_ID << 128) + weaponNextTokenId++;
        weaponsMinted[id] = WeaponTraits(true, damageLevel, rarityLevel, size, colour);
        _mint(msg.sender, id, 1, "");
        emit WeaponMinted(msg.sender, id, uint8(damageLevel), uint8(rarityLevel), uint8(size), uint8(colour));
    }

    // TODO: do player has to know the entire ID (collection ID + token ID) or just token ID?
    function checkUniqueWeaponTraits(uint256 tokenId) external view returns (WeaponTraits memory) {
        require(weaponsMinted[tokenId].minted, "this weapon is not minted");
        return weaponsMinted[tokenId];
    }

    // player will be randomly given a legendary artifact based on current block hash, player's addresss and current artifact token ID
    // player's address and current block hash are not sufficient to create unique artifact if player has two txs in the same block
    // that's why we need some kind of auto-incrementing nonce value to make it more unique, and current artifact token ID will do the trick
    function mintLegendaryArtifact() external payable {
        require(players[msg.sender], "address is not a registered player");
        require(artifactNextTokenId < artifactsLimit, "limit of allowed minted legendary artifacts was reached");
        uint256 artifactCost = baseArtifactCost + (multiplierArtifactCost * artifactNextTokenId);
        require(
            balanceOf(msg.sender, RARE_LINK_COLLECTION_ID << 128) >= artifactCost,
            "player doesn't have enough rare links to purchase this legendary artifact"
        );

        // before we burn player's rare link token, we will bring them back to the total supply
        rareLinkTokenSupply += artifactCost;
        _burn(msg.sender, RARE_LINK_COLLECTION_ID << 128, artifactCost);

        // randomly generate traits for the legendary artifact, even though this is not safe from attacks
        // but it is sufficient to generate some kind of bitmap (256 bits) and each bit represent having or not having a certain "legendary" trait
        // TODO create a helper external function that will provide a decription for this bitmap
        bytes32 legendaryTraits = keccak256(abi.encode(blockhash(block.number), msg.sender, artifactNextTokenId));
        uint256 id = (ARTIFACT_COLLECTION_ID << 128) + artifactNextTokenId++;
        legendaryArtifactsMinted[id] = legendaryTraits;
        _mint(msg.sender, id, 1, "");
        emit LegendaryArtifactMinted(msg.sender, id, legendaryTraits);
    }

    // TODO: do player has to know the entire ID (collection ID + token ID) or just token ID?
    function checkLegendaryArtifactTraits(uint256 tokenId) external view returns (bytes32) {
        require(legendaryArtifactsMinted[tokenId] != bytes32(0), "this legendary artifact is not minted");
        return legendaryArtifactsMinted[tokenId];
    }

    // TODO: add minting for potions, I want potions to be fungible, and each collection will be for a different potion "type"
}
