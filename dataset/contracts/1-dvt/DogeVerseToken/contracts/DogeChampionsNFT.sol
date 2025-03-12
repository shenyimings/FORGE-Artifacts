// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "contracts/ITournament.sol";
import "contracts/DogeChampionsConsumable.sol";

contract DogeChampionsNFT is Initializable, OwnableUpgradeable, ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable
{
    event Mint(address minter, uint256 tokenId);
    event Enhance(uint256 tokenId, uint256 consumableId, int256 valueChange);
    event PlayableIdRemoved(address walletAddress, uint256 tokenId);
    event PlayableIdAdded(address walletAddress, uint256 tokenId);
    event BaseURIChanged(string newBaseURI);

    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter public _tokenIds;
    CountersUpgradeable.Counter private randomizationNonce;
    CountersUpgradeable.Counter public numberOfNormalMints;
    CountersUpgradeable.Counter public numberOfTournamentMints;
    CountersUpgradeable.Counter public mintPhase;

    mapping(address => uint256) private initialMintDiscountWhitelist;
    mapping(address => uint256) private finalMintDiscountWhitelist;
    mapping(address => uint256) private collaboratorWhitelist;

    mapping(uint256 => uint256) public tokenIdToAttackPower;
    mapping(uint256 => uint256) public tokenIdToDefensePower;
    mapping(uint256 => uint256) public tokenIdToCRTRate;
    mapping(uint256 => uint256) public tokenIdToPassive;
    mapping(uint256 => uint256) public tokenIdToElement;
    mapping(uint256 => uint256) public tokenIdToRarity;
    mapping(uint256 => address) public tokenIdToMinter;

    mapping(address => uint256[]) public walletToPlayableTokenIds;

    mapping(uint256 => address) public playableTokenIdToUser;

    mapping(uint256 => uint256[]) public tokenIdToUsedConsumableHistory;
    mapping(uint256 => int256[]) public tokenIdToPropertyValueChangeHistory;

    uint256 public discountedMintPrice;
    uint256 public initialMintPrice;
    uint256 public finalMintPrice;

    /*
     * @author finite total supply is 30,000
     * First Mint Phase: 10,400 mint
     * Second Mint Phase: 10,400 mint
     * Total Tournament Mint: 9,200
     */
    uint256 constant normalMintLimit = 10400; // 10K sale and 400 giveaway for each phase
    uint256 constant tournamentMintLimit = 9200; // total tournament mint count

    address private marketplaceAddress;

    bool private isMintAvailable;

    bool private ignoreDiscountWhitelist;

    bool public isMigrationOver;

    ITournament private dogeChampionsTournament;
    DogeChampionsConsumable private dogeChampionsConsumable;

    // percentage rates of property determination. These will be used to set Boost Events
    uint256 public firstChancePercent;
    uint256 public secondChancePercent;
    uint256 public thirdChancePercent;
    uint256 public forthChancePercent;

    string private baseURIOverride; // format => ipfs://CustomCIDHashToBeSet/

    /*
     * @author required override for ERC721Enumerable
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /*
     * @author required override for ERC721Enumerable
     */
    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    /*
     * @author required override for ERC721Enumerable
     */
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /*
     * @author required override for ERC721Enumerable
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /*
     * @author optional override for baseURI.
     */
    function _baseURI() internal view override returns (string memory)
    {
        return baseURIOverride;
    }

    /*
     * @author override for transfer to update 
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        super._transfer(from, to, tokenId);
        if(to == marketplaceAddress ||from == marketplaceAddress)
            return;
            
        _removeFromPlayableIds(from, tokenId);
        _pushToPlayableIds(to, tokenId);
    }

    /*
     * @author modifier that prevents calls from addresses rather than DogeChampionsMarketplace contract
     */
    modifier onlyMarketplace
    {
        require(msg.sender == marketplaceAddress, "Only DogeChampionsMarketplace contract can access this function.");
        _;
    }

    /*
     * @author plain good old constructor
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor()
    {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Ownable_init();
        __ERC721_init("DogeChampionsNFT", "DOGECHMP");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();

        configureMint();

        firstChancePercent = 60;
        secondChancePercent = 90;
        thirdChancePercent = 98;
        forthChancePercent = 100;

        discountedMintPrice = 0.11 ether;
        initialMintPrice = 0.22 ether;
        finalMintPrice = 0.55 ether;

        isMintAvailable = false;
        ignoreDiscountWhitelist = false;
        isMigrationOver = false;
    }

    /*
     * @author configures the mint phase. No more than 2 mint phases can be established
     */
    function configureMint() public onlyOwner
    {
        require(mintPhase.current() < 2, "No more mint phase can be started. We already ran 2 mint phases.");
        mintPhase.increment();

        numberOfNormalMints.reset();
    }
    
    /*
     * @author calculates random number full on-chain using randomized nonce and keccak
     */
    function calculateRandomness(uint256 modulus) internal returns(uint256)
    {
        randomizationNonce.increment(); 
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randomizationNonce.current()))) % modulus;
    }

    /*
     * @author validates if given tokenId is playable by user
     */
    function validatePlayability(address walletAddress, uint256 tokenId) public view returns(bool)
    {
        return playableTokenIdToUser[tokenId] == walletAddress;
    }

    /*
     * @author validates if given tokenIds are playable by user
     */
    function validatePlayability(address walletAddress, uint256[4] memory tokenIds) public view returns(bool)
    {
        bool zeroValidation = false;
        bool containsNonPlayableTokenId = false;
        for(uint256 i = 0; i < 4; i++)
        {
            if(tokenIds[i] != 0)
            {
                zeroValidation = true;
                if(playableTokenIdToUser[tokenIds[i]] != walletAddress)
                {
                    containsNonPlayableTokenId = true;
                    break;
                }
            }
        }

        return zeroValidation && !containsNonPlayableTokenId;
    }

    /*
     * @author re-evaluates given tokenId's property depending on consumableTokenId
     */
    function enhanceProperty(uint256 tokenId, uint256 consumableTokenId) public
    {
        require(tokenId <= _tokenIds.current(), "There is no such NFT.");
        require(consumableTokenId >= 0 && consumableTokenId < 6, "There is no such consumable type.");
        require(dogeChampionsConsumable.balanceOf(msg.sender, consumableTokenId) > 0, "You don't have enough consumable.");
        require(ownerOf(tokenId) == msg.sender, "Can't enhance properties of not owned NFT.");

        dogeChampionsConsumable.burn(consumableTokenId, msg.sender);

        if(consumableTokenId < 3)
        {
            enhance(tokenId, consumableTokenId, false);
        }
        else
        {
            enhance(tokenId, consumableTokenId, true);
        }
    }

    /*
     * @author helper internal function for enhancing properties using normal consumable
     */
    function enhance(uint256 tokenId, uint256 consumableTokenId, bool isPremium) internal
    {
        int256 valueChange;
        if(consumableTokenId % 3 == 0)
        {
            valueChange = determinePower(true, tokenId, isPremium);
        }
        else if(consumableTokenId % 3 == 1)
        {
            valueChange = determinePower(false, tokenId, isPremium);
        }
        else if(consumableTokenId % 3 == 2)
        {
            valueChange = determineCRTRate(tokenId, isPremium);
        }

        tokenIdToUsedConsumableHistory[tokenId].push(consumableTokenId); 
        tokenIdToPropertyValueChangeHistory[tokenId].push(valueChange);

        emit Enhance(tokenId, consumableTokenId, valueChange);
    }

    // @author following region is for mint related functions

    /*
     * @author mints a DogeChampionsNFT for regular mint price on current mint phase
     */
    function publicMint(bool isDiscountMint, uint256 amount) public payable returns (uint256)
    {
        require(isMintAvailable == true, "Minting is not started yet.");
        require(numberOfNormalMints.current() + amount <= normalMintLimit, "Decrease amount of mint, not enough supply left.");

        if (isDiscountMint) {
            require(!ignoreDiscountWhitelist, "Discount period ended.");
            if(mintPhase.current() < 2)
            {
                require(initialMintDiscountWhitelist[msg.sender] >= amount, "You don't have enough WL credit.");
                initialMintDiscountWhitelist[msg.sender] = initialMintDiscountWhitelist[msg.sender] - amount;
            }
            else
            {
                require(finalMintDiscountWhitelist[msg.sender] >= amount, "You don't have enough WL credit.");
                finalMintDiscountWhitelist[msg.sender] = finalMintDiscountWhitelist[msg.sender] - amount;
            }
            require(msg.value == discountedMintPrice * amount, "Please submit the exact price to mint a Doge Champion.");
        } else {
            if(mintPhase.current() < 2)
            {
                require(msg.value == initialMintPrice * amount, "Please submit the exact price to mint DogeChampionsNFT.");
            }
            else
            {
                require(msg.value == finalMintPrice * amount, "Please submit the exact price to mint DogeChampionsNFT.");
            }
        }
        
        payable(owner()).transfer(msg.value);

        for(uint256 i = 0; i < amount; i++)
        {
            _tokenIds.increment();
            numberOfNormalMints.increment();
            mint(false, 0);
        }

        return _tokenIds.current();
    }

    /*
     * @author mints a DogeChampionsNFT for free - only tournament winners and collaborators
     */
    function freeMint(bool isTournamentMint, uint256 amount, uint256 rarity) public
    {
        require(isMintAvailable == true, "Minting is not started yet.");
        require(numberOfNormalMints.current() + amount <= normalMintLimit, "Decrease amount of mint, not enough supply left.");

        if (isTournamentMint) {
            require(numberOfTournamentMints.current() < tournamentMintLimit, "We hit tournament mint limit.");
            uint256[] memory rewards = dogeChampionsTournament.getRewards(msg.sender);
            require(rarity < 5, "There is no such NFT rarity.");
            require(rewards[rarity] >= amount, "You don't have NFT rewards.");

            for(uint256 i = 0; i < amount; i++)
            {
                _tokenIds.increment();
                numberOfTournamentMints.increment();
                mint(true, rarity);
            }

            dogeChampionsTournament.decreaseReward(rarity, msg.sender);
        } else {
            require(collaboratorWhitelist[msg.sender] >= amount, "You don't have enough credit.");

            for(uint256 i = 0; i < amount; i++)
            {
                _tokenIds.increment();
                numberOfNormalMints.increment();
                mint(false, 0);
            }
            collaboratorWhitelist[msg.sender] = collaboratorWhitelist[msg.sender] - amount;
        }

    }

    /*
     * @author this function is going to be used by owner during the version 2 update migration. After all NFTs
     * from DogeChampions V1 migrated, we will set isMigrationOver flag to false and this function won't be
     * available for further use.
     */
    function migrationMint(uint256 rarity, uint256 element, uint256 attack, uint256 defense, uint256 crt, uint256 passive, string memory uri, address tokenOwner, bool isOnSale) public onlyOwner
    {
        require(!isMigrationOver, "This function can only be called during V2 migration.");
        _tokenIds.increment();
        numberOfNormalMints.increment();
        uint256 newItemId = _tokenIds.current();

        tokenIdToRarity[newItemId] = rarity;
        tokenIdToElement[newItemId] = element;
        tokenIdToAttackPower[newItemId] = attack;
        tokenIdToDefensePower[newItemId] = defense;
        tokenIdToCRTRate[newItemId] = crt;
        tokenIdToPassive[newItemId] = passive;

        address owner = isOnSale ? marketplaceAddress : tokenOwner;

        _mint(owner, newItemId);
        
        _setTokenURI(newItemId, uri);
        setApprovalForAll(marketplaceAddress, true);

        _pushToPlayableIds(tokenOwner, newItemId);

        tokenIdToMinter[_tokenIds.current()] = tokenOwner;
        
        emit Mint(owner, _tokenIds.current());
    }

    /*
     * @author generic mint function for different price mints functions to consume
     */
    function mint(bool isTournamentMint, uint256 tournamentMintRarity) internal 
    {
        uint256 newItemId = _tokenIds.current();

        determineRarity(newItemId, isTournamentMint, tournamentMintRarity);
        determineElement(newItemId);
        determinePower(true, newItemId, false);
        determinePower(false, newItemId, false);
        determineCRTRate(newItemId, false);
        determinePassive(newItemId);

        string memory firstPart = string(abi.encodePacked(StringsUpgradeable.toString(determineBackgroundLayer(newItemId)), "-", StringsUpgradeable.toString(calculateRandomness(18)/*weapon*/), "-", StringsUpgradeable.toString(tokenIdToElement[newItemId]/*skin*/), "-"));
        string memory secondPart = string(abi.encodePacked(StringsUpgradeable.toString(calculateRandomness(16)/*face*/), "-", StringsUpgradeable.toString(calculateRandomness(8)/*eye*/), "-", StringsUpgradeable.toString(calculateRandomness(12)/*mouth*/), "-"));
        string memory thirdPart = string(abi.encodePacked(StringsUpgradeable.toString(calculateRandomness(23)/*glasses*/), "-", StringsUpgradeable.toString(calculateRandomness(116)/*outfit*/), "-", StringsUpgradeable.toString(calculateRandomness(93)/*head*/), ".json"));

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, string(abi.encodePacked(firstPart, secondPart, thirdPart)));
        setApprovalForAll(marketplaceAddress, true);

        _pushToPlayableIds(msg.sender, newItemId);

        tokenIdToMinter[_tokenIds.current()] = msg.sender;

        emit Mint(msg.sender, _tokenIds.current());
    }

    // @author following region is for determining a DogeChampionsNFT's properties during mint

    /*
     * @author determines rarity of user's DogeChampionsNFT randomly on-chain during mint
     */
    function determineRarity(uint256 tokenId, bool isTournamentMint, uint256 tournamentRarity) internal
    {
        if(isTournamentMint)
        {
            tokenIdToRarity[tokenId] = tournamentRarity;
            return;
        }

        uint256 randomNumber = calculateRandomness(200); // using 200 as limit to be more precise on floating points

        if(randomNumber >= 0 && randomNumber < 80) // 40% chance
            tokenIdToRarity[tokenId] = 0; // un-common
        else if(randomNumber >= 80 && randomNumber < 140) // 30% chance
            tokenIdToRarity[tokenId] = 1; // common
        else if(randomNumber >= 140 && randomNumber < 180) // 20% chance
            tokenIdToRarity[tokenId] = 2; // rare
        else if(randomNumber >= 180 && randomNumber < 199) // 9.5% chance
            tokenIdToRarity[tokenId] = 3; // epic
        else if(randomNumber >= 199 && randomNumber < 200) // 0.5% chance
            tokenIdToRarity[tokenId] = 4; // legendary
    }

    /*
     * @author determines element of user's DogeChampionsNFT randomly on-chain during mint
     */
    function determineElement(uint256 tokenId) internal
    {
        uint256 randomNumber = calculateRandomness(40);

        if(randomNumber >= 0 && randomNumber < 9)
            tokenIdToElement[tokenId] = 0;
        else if(randomNumber >= 9 && randomNumber < 19)
            tokenIdToElement[tokenId] = 1;
        else if(randomNumber >= 19 && randomNumber < 29)
            tokenIdToElement[tokenId] = 2;
        else if(randomNumber >= 29 && randomNumber < 39)
            tokenIdToElement[tokenId] = 3;
    }

    /*
     * @author determines background layer of user's DogeChampionsNFT randomly on-chain during mint
     */
    function determineBackgroundLayer(uint256 tokenId) internal returns (uint256)
    {
        uint256 rarityIndicator = tokenIdToRarity[tokenId];
        uint256 randomNumber = calculateRandomness(100);
        uint256 candidateBackgroundLayer;


        if(rarityIndicator == 4) // legendary card
        {
            if(randomNumber >= 0 && randomNumber < 33)
                candidateBackgroundLayer = 10;
            else if(randomNumber >= 33 && randomNumber < 66)
                candidateBackgroundLayer = 11;
            else if(randomNumber >= 66 && randomNumber < 100)
                candidateBackgroundLayer = 12;
        }
        else if(rarityIndicator == 3) // epic card
        {
            if(randomNumber >= 0 && randomNumber < 50)
                candidateBackgroundLayer = 8;
            else if(randomNumber >= 50 && randomNumber < 100)
                candidateBackgroundLayer = 9;
        }
        else if(rarityIndicator == 2) // rare card
        {
            if(randomNumber >= 0 && randomNumber < 50)
                candidateBackgroundLayer = 6;
            else if(randomNumber >= 50 && randomNumber < 100)
                candidateBackgroundLayer = 7;
        }
        else if(rarityIndicator == 1) // uncommon card
        {
            if(randomNumber >= 0 && randomNumber < 50)
                candidateBackgroundLayer = 4;
            else if(randomNumber >= 50 && randomNumber < 100)
                candidateBackgroundLayer = 5;
        }
        else // common card
        {
            if(randomNumber >= 0 && randomNumber < 25)
                candidateBackgroundLayer = 0;
            else if(randomNumber >= 25 && randomNumber < 50)
                candidateBackgroundLayer = 1;
            else if(randomNumber >= 50 && randomNumber < 75)
                candidateBackgroundLayer = 2;
            else if(randomNumber >= 75 && randomNumber < 100)
                candidateBackgroundLayer = 3;
        }

        return candidateBackgroundLayer;
    }

    /*
     * @author determines attack & defense power peoperty of user's DogeChampionsNFT randomly on-chain during mint
     */
    function determinePower(bool isAttack, uint256 tokenId, bool isPremiumEnhance) internal returns (int256)
    {
        uint256 rarityIndicator = tokenIdToRarity[tokenId];
        uint256 powerCandidate;

        uint256 percent = calculateRandomness(100);

        if(percent < firstChancePercent) // 60% chance
        {
            powerCandidate = calculateRandomness(20) + 50; // 50 - 69 power
        }
        else if(percent < secondChancePercent) // 30% chance
        {
            powerCandidate = calculateRandomness(10) + 70; // 70 - 79 power
        }
        else if(percent < thirdChancePercent) // 8% chance
        {
            powerCandidate = calculateRandomness(10) + 80; // 80 - 89 power
        }
        else if(percent < forthChancePercent) // 2% chance
        {
            powerCandidate = calculateRandomness(10) + 90; // 90 - 99 power
        }

        if(powerCandidate == 99)
            powerCandidate = 100;

        for(uint256 i = 0; i < rarityIndicator; i++)
            powerCandidate *= 2;

        if(isAttack) {
            if(isPremiumEnhance)
            {
                if(powerCandidate > tokenIdToAttackPower[tokenId])
                {
                    uint256 oldValue = tokenIdToAttackPower[tokenId];
                    tokenIdToAttackPower[tokenId] = powerCandidate;
                    return int256(powerCandidate) - int256(oldValue);
                }
                return 0;
            }
            else
            {
                uint256 oldValue = tokenIdToAttackPower[tokenId];
                tokenIdToAttackPower[tokenId] = powerCandidate;
                return int256(powerCandidate) - int256(oldValue);
            }
        } else {
            if(isPremiumEnhance)
            {
                if(powerCandidate > tokenIdToDefensePower[tokenId])
                {
                    uint256 oldValue = tokenIdToDefensePower[tokenId];
                    tokenIdToDefensePower[tokenId] = powerCandidate;
                    return int256(powerCandidate) - int256(oldValue);
                }
                return 0;
            }
            else
            {
                uint256 oldValue = tokenIdToDefensePower[tokenId];
                tokenIdToDefensePower[tokenId] = powerCandidate;
                return int256(powerCandidate) - int256(oldValue);
            }
        }
    }

    /*
     * @author determines CRT rate peoperty of user's DogeChampionsNFT randomly on-chain during mint
     */
    function determineCRTRate(uint256 tokenId, bool isPremiumEnhance) internal returns(int256)
    {
        uint256 CRTRateCandidate;

        uint256 percent = calculateRandomness(100);

        if(percent < 60) // 60% chance
        {
            CRTRateCandidate = calculateRandomness(4) + 2; // 2 - 5 CRT rate
        }
        else if(percent < 90) // 30% chance
        {
            CRTRateCandidate = calculateRandomness(3) + 6; // 6 - 8 CRT rate
        }
        else if(percent < 98) // 8% chance
        {
            CRTRateCandidate = calculateRandomness(2) + 9; // 9 - 10 CRT rate
        }
        else if(percent < 100) // 2% chance
        {
            CRTRateCandidate = calculateRandomness(2) + 11; // 11 - 12 CRT rate
        }

        if(isPremiumEnhance)
        {
            if(CRTRateCandidate > tokenIdToCRTRate[tokenId])
            {
                uint256 oldValue = tokenIdToCRTRate[tokenId];
                tokenIdToCRTRate[tokenId] = CRTRateCandidate;
                return int256(CRTRateCandidate) - int256(oldValue);
            }
            return 0;
        }
        else
        {
            uint256 oldValue = tokenIdToCRTRate[tokenId];
            tokenIdToCRTRate[tokenId] = CRTRateCandidate;
            return int256(CRTRateCandidate) - int256(oldValue);
        }
    }

    /*
     * @author determines passive skill of user's DogeChampionsNFT randomly on-chain during mint
     */
    function determinePassive(uint256 tokenId) internal
    {
        uint256 randomNumber = calculateRandomness(100);

        if(randomNumber >= 0 && randomNumber < 25) // 25% chance
            tokenIdToPassive[tokenId] = 1; // additional 3 normal turns for each Doge Champion
        else if(randomNumber >= 25 && randomNumber < 40) // 15% chance
            tokenIdToPassive[tokenId] = 2; // additional 1 CRT turn for each Doge Champion
        else if(randomNumber >= 40 && randomNumber < 65) // 25% chance
            tokenIdToPassive[tokenId] = 3; // everyone 5% more attack power
        else if(randomNumber >= 65 && randomNumber < 80) // 15% chance
            tokenIdToPassive[tokenId] = 4; // everyone 10% more attack power
        else if(randomNumber >= 80 && randomNumber < 95) // 15% chance
            tokenIdToPassive[tokenId] = 5; // same element 10% more attack power
        else if(randomNumber >= 95 && randomNumber < 100) // 5% chance
            tokenIdToPassive[tokenId] = 6; // same element 20% more attack power

    }

    // @author following region is for altering playable tokenIds of given user

    /*
     * @author adds a new tokenId for given user into playable ids map
     */
    function pushToPlayableIds(address walletAddress, uint256 tokenId) public onlyMarketplace
    {
        _pushToPlayableIds(walletAddress, tokenId);
    }

    /*
     * @author adds a new tokenId for given user into playable ids map internally
     */
    function _pushToPlayableIds(address walletAddress, uint256 tokenId) internal
    {
        walletToPlayableTokenIds[walletAddress].push(tokenId);
        playableTokenIdToUser[tokenId] = walletAddress;
        emit PlayableIdAdded(walletAddress, tokenId);
    }

    /*
     * @author removes given tokenId for given user from playable ids map
     */
    function removeFromPlayableIds(address walletAddress, uint256 tokenId) public onlyMarketplace
    {
        _removeFromPlayableIds(walletAddress, tokenId);
    }

    /*
     * @author removes given tokenId for given user from playable ids map internally
     */
    function _removeFromPlayableIds(address walletAddress, uint256 tokenId) internal
    {
        uint256[] memory playableIdArray = walletToPlayableTokenIds[walletAddress];

        if(playableIdArray.length == 0)
            return;
            
        uint256[] memory newArray = new uint256[](playableIdArray.length - 1);

        uint256 j = 0;
        for(uint256 i = 0; i < playableIdArray.length; i++)
        {
            if(playableIdArray[i] != tokenId)
            {
                newArray[j] = playableIdArray[i];
                j += 1;
            }
        }

        walletToPlayableTokenIds[walletAddress] = newArray;
        playableTokenIdToUser[tokenId] = address(0);
        emit PlayableIdRemoved(walletAddress, tokenId);
    }

    /*
     * @author sets isMigrationOver flag to false to cancel usage of migration mint function
     */
    function finalizeMigration() public onlyOwner
    {
        require(!isMigrationOver, "Migration mint flag can be set only once to false.");
        isMigrationOver = true;
    }

    // @author Following region is for getter functions

    /*
     * @author returns attack powers of given tokenIds. This is consumed by tournament contract
     */
    function getAttackPowers(uint256[4] memory tokenIds) public view returns(uint256[4] memory result)
    {
        result = [tokenIdToAttackPower[tokenIds[0]],
                  tokenIdToAttackPower[tokenIds[1]],
                  tokenIdToAttackPower[tokenIds[2]],
                  tokenIdToAttackPower[tokenIds[3]]];
        
        return result;
    }

    /*
     * @author returns rarity of given token id
     */
    function getRarity(uint256 tokenId) public view returns(uint256)
    {    
        return tokenIdToRarity[tokenId];
    }

    /*
     * @author returns elements and rarities for given tokenIds. This is consumed by tournament contract
     */
    function getElementsAndRarities(uint256[4] memory tokenIds) public view returns(uint256[4] memory elements, uint256[4] memory rarities)
    {
        elements = [tokenIdToElement[tokenIds[0]],
                    tokenIdToElement[tokenIds[1]],
                    tokenIdToElement[tokenIds[2]],
                    tokenIdToElement[tokenIds[3]]];

        rarities = [tokenIdToRarity[tokenIds[0]],
                  tokenIdToRarity[tokenIds[1]],
                  tokenIdToRarity[tokenIds[2]],
                  tokenIdToRarity[tokenIds[3]]];
        
        return (elements, rarities);
    }

    /*
     * @author returns attack, defense, CRT and passive skills for given tokenIds. This is consumed by tournament contract
     */
    function getTournamentValues(uint256[4] memory tokenIds) public view returns(uint256[4] memory attackPowers, uint256[4] memory defensePowers, uint256[4] memory crtRates, uint256[4] memory passiveSkills)
    {
        attackPowers = [tokenIdToAttackPower[tokenIds[0]],
                    tokenIdToAttackPower[tokenIds[1]],
                    tokenIdToAttackPower[tokenIds[2]],
                    tokenIdToAttackPower[tokenIds[3]]];

        defensePowers = [tokenIdToDefensePower[tokenIds[0]],
                  tokenIdToDefensePower[tokenIds[1]],
                  tokenIdToDefensePower[tokenIds[2]],
                  tokenIdToDefensePower[tokenIds[3]]];

        crtRates = [tokenIdToCRTRate[tokenIds[0]],
                  tokenIdToCRTRate[tokenIds[1]],
                  tokenIdToCRTRate[tokenIds[2]],
                  tokenIdToCRTRate[tokenIds[3]]];

        passiveSkills = [tokenIdToPassive[tokenIds[0]],
                  tokenIdToPassive[tokenIds[1]],
                  tokenIdToPassive[tokenIds[2]],
                  tokenIdToPassive[tokenIds[3]]];
        
        return (attackPowers, defensePowers, crtRates, passiveSkills);
    }

    /*
     * @author returns all values for given tokenId.
     */
    function getAllValues(uint256[] memory tokenIds) public view returns(uint256[] memory attacks,
                                                               uint256[] memory defenses,
                                                               uint256[] memory crts,
                                                               uint256[] memory passives,
                                                               uint256[] memory rarities,
                                                               uint256[] memory elements,
                                                               string[] memory uris)
    {
        attacks = new uint[](tokenIds.length);
        defenses = new uint[](tokenIds.length);
        crts = new uint[](tokenIds.length);
        passives = new uint[](tokenIds.length);
        rarities = new uint[](tokenIds.length);
        elements = new uint[](tokenIds.length);
        uris = new string[](tokenIds.length);

        for(uint256 i = 0; i < tokenIds.length; i++)
        {
            attacks[i] = tokenIdToAttackPower[tokenIds[i]];
            defenses[i] = tokenIdToDefensePower[tokenIds[i]];
            crts[i] = tokenIdToCRTRate[tokenIds[i]];
            passives[i] = tokenIdToPassive[tokenIds[i]];
            rarities[i] = tokenIdToRarity[tokenIds[i]];
            elements[i] = tokenIdToElement[tokenIds[i]];
            uris[i] = tokenURI(tokenIds[i]);
        }

        return (attacks,
                defenses,
                crts,
                passives,
                rarities,
                elements,
                uris);
    }

    /*
     * @author returns history of used consumables on given tokenId
     */
    function getConsumableHistory(uint256 tokenId) public view returns(uint256[] memory, int256[] memory)
    {
        uint256[] memory usedConsumableHistoryArray = tokenIdToUsedConsumableHistory[tokenId];
        int256[] memory valueChangeHistoryArray = tokenIdToPropertyValueChangeHistory[tokenId];
        uint256 length = usedConsumableHistoryArray.length;

        if(length < 10)
        {
            uint256[] memory history = new uint256[](length);
            int256[] memory valueChange = new int256[](length);
            for(uint256 i = 0; i < length; i++)
            {
                history[i] = usedConsumableHistoryArray[i];
                valueChange[i] = valueChangeHistoryArray[i];
            }
            return (history, valueChange);
        }
        else
        {
            uint256[] memory history = new uint256[](10);
            int256[] memory valueChange = new int256[](10);
            uint256 historyIndex = length - 10;
            for(uint256 i = 0; i < 10; i++)
            {
                history[i] = usedConsumableHistoryArray[historyIndex];
                valueChange[i] = valueChangeHistoryArray[historyIndex];
                historyIndex++;
            }
            return (history, valueChange);
        }
    }

    /*
     * @author returns minter of given tokenId
     */
    function getMinterOfToken(uint256 tokenId) public view returns(address)
    {
        return tokenIdToMinter[tokenId];
    }

    /*
     * @author returns playable tokenIds of given user. After users mint / purchase
     * DogeChampionsNFT, they will be able to see minted / purchased tokenId even
     * if they start selling their NFTs on marketplace. This is to prevent users
     * stop their sales on our marketplace to enter tournaments.
     */
    function getPlayableIds(address walletAddress) public view returns(uint256[] memory)
    {
        return walletToPlayableTokenIds[walletAddress];
    }

    // @author Following region is for setter functions

    /*
     * @author sets property determination rates. We are going to use this method for setting Boost Events
     */
    function setPropertyDeterminationRates(uint256 first, uint256 second, uint256 third) public onlyOwner
    {
        require(first > 0, "Minimum percent should be 1.");
        require(first < second && second < third && third < 100, "Percentages should be in order and less than 100.");
        require(isMintAvailable == false, "This can't be changed during the mint.");

        firstChancePercent = first;
        secondChancePercent = second;
        thirdChancePercent = third;
    }

    /*
     * @author sets mint price. Send x1000 of the value for price
     */
    function setMintPrices(uint256 price, uint256 discountPrice) public onlyOwner
    {
        require(price >= 0, "Price should be greater than or equal to 0.");
        require(discountPrice >= 0, "Discount price should be greater than or equal to 0.");
        if(mintPhase.current() < 2)
            initialMintPrice = price * (0.001 ether);
        else
            finalMintPrice = price * (0.001 ether);

        discountedMintPrice = price * (0.001 ether);
    }

    /*
     * @author sets baseURIOverride with given uri
     */
    function setBaseURI(string memory uri) public onlyOwner
    {
        baseURIOverride = uri;
        emit BaseURIChanged(baseURIOverride);
    }

    /*
     * @author sets ignoreDiscountWhitelist flag
     */
    function setIgnoreDiscountFlag(bool shouldIgnore) public onlyOwner
    {
        ignoreDiscountWhitelist = shouldIgnore;
    }

    function setContracts(address tournamentContract, address consumableContract, address marketplaceContract) public onlyOwner {
        dogeChampionsTournament = ITournament(tournamentContract);
        dogeChampionsConsumable = DogeChampionsConsumable(consumableContract);
        marketplaceAddress = marketplaceContract;
    }

    /*
     * @author sets availability flag of public mint. If set to false, nobody can mint NFTs
     */
    function setMintAvailability(bool isAvailable) public onlyOwner
    {
        isMintAvailable = isAvailable;
    }

    /*
     * @author sets number of free mints for given user into collaborator whitelist map
     */
    function setAddressToCollaboratorWhitelist(address walletAddress, uint256 amount) public onlyOwner
    {
        collaboratorWhitelist[walletAddress] = amount;
    }

    /*
     * @author puts given user into presale whitelist map according to mint phase
     */
    function setAddressToDiscountWhitelist(address walletAddress, uint256 amount) public onlyOwner
    {
        if(mintPhase.current() < 2){
            initialMintDiscountWhitelist[walletAddress] = amount;
        }else {
            finalMintDiscountWhitelist[walletAddress] = amount;
        }
    }
}