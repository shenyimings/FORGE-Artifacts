// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

import "contracts/ITournament.sol";

contract DogeChampionsConsumable is Initializable, ERC1155Upgradeable, ERC1155SupplyUpgradeable, OwnableUpgradeable
{
    uint256 private constant ATTACK_NORMAL = 0;
    uint256 private constant DEFENSE_NORMAL = 1;
    uint256 private constant CRT_NORMAL = 2;
    uint256 private constant ATTACK_PREMIUM = 3;
    uint256 private constant DEFENSE_PREMIUM = 4;
    uint256 private constant CRT_PREMIUM = 5;

    mapping(uint256 => uint256) private bundleIdToBundle;
    mapping(uint256 => uint256) private bundleIdToPrice;

    uint256 private premiumPrice;

    address private marketplaceAddress;

    bool private areBundlesAvailable;

    ITournament private dogeChampionsTournament;
    address private dogeChampionsNFTContractAddress;
    mapping(address => bool) public dogeChampionsProtocolMap;

    // events related fields

    bool isConsumeFrenzyEventActive;
    uint256 activeConsumeFrenzyEventId;
    uint256 consumeFrenzyEventEntranceCount;
    uint256 consumeFrenzyEventRewardCount;
    mapping(uint256 => mapping(address => uint256)) userToUsedConsumable;

    bool isPremiumEventActive;
    uint256 premiumEventEntranceCount;
    uint256 premiumEventRewardCount;

    bool public isMigrationOver;

    /*
     * @author modifier that prevents calls from addresses rather than DogeChampionsNFT contract
     */
    modifier onlyDogeChampionsNFT
    {
        require(msg.sender == dogeChampionsNFTContractAddress, "Only DogeChampionsNFT contract can access this function.");
        _;
    }

    /*
     * @author modifier that prevents calls from addresses rather than DogeChampionsNFT contract
     */
    modifier onlyDogeChampionsProtocols
    {
        require(dogeChampionsProtocolMap[msg.sender], "Only DogeChampions protocols can access this function.");
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
        __ERC1155_init("ipfs://QmesZgjyaa4R1Jm88XtBzXB7BE77zQVc4bMrT8mHbqYj1D/{id}.json");
        __ERC1155Supply_init();
        __Ownable_init();

        // mint 20 unit from each consumable type to deployer for testing purposes on production
        _mint(msg.sender, ATTACK_NORMAL, 20, "");
        _mint(msg.sender, DEFENSE_NORMAL, 20, "");
        _mint(msg.sender, CRT_NORMAL, 20, "");
        _mint(msg.sender, ATTACK_PREMIUM, 20, "");
        _mint(msg.sender, DEFENSE_PREMIUM, 20, "");
        _mint(msg.sender, CRT_PREMIUM, 20, "");

        bundleIdToBundle[0] = 5;
        bundleIdToPrice[0] = 0.25 ether;

        bundleIdToBundle[1] = 10;
        bundleIdToPrice[1] = 2 ether;

        bundleIdToBundle[2] = 20;
        bundleIdToPrice[2] = 3 ether;

        bundleIdToBundle[3] = 30;
        bundleIdToPrice[3] = 4 ether;

        bundleIdToBundle[4] = 40;
        bundleIdToPrice[4] = 5 ether;

        areBundlesAvailable = false;

        isConsumeFrenzyEventActive = false;
        isPremiumEventActive = false;

        activeConsumeFrenzyEventId = 0;

        premiumPrice = 0.1 ether;

        isMigrationOver = false;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /*
     * @author sets marketplace contract related fields
     */
    function setMarketplaceContractAddress(address contractAddress) public onlyOwner
    {
        marketplaceAddress = contractAddress;
    }

    /*
     * @author sets tournament contract related fields
     */
    function setTournamentContract(address contractAddress) public onlyOwner
    {
        dogeChampionsTournament = ITournament(contractAddress);
    }

    /*
     * @author sets DogeChampionsNFT contract related fields
     */
    function setNFTContract(address contractAddress) public onlyOwner
    {
        dogeChampionsNFTContractAddress = contractAddress;
    }

    /*
     * @author sets DogeChampionsProtocol map state
     */
    function setStakeProtocolContract(address contractAddress, bool value) public onlyOwner
    {
        dogeChampionsProtocolMap[contractAddress] = value;
    }

    /*
     * @author sets premium consumable price. Send x1000 higher value for price in parameter.
     */
    function setPremiumPrice(uint256 price) public onlyOwner
    {
        require(price >= 0, "Price should be greater than or equal to 0.");
        premiumPrice = price * (0.001 ether);
    }

    /*
     * @author mints random consumables to user if he / she has enough consumable reward
     */
    function mint(uint256 amount) public 
    {
        uint256[] memory rewards = dogeChampionsTournament.getRewards(msg.sender);
        require(rewards[5] >= amount, "You don't have enough Consumable rewards.");

        for(uint256 i = 0; i < amount; i++)
        {
            uint256 tokenId = calculateConsumableType(i + 1 + amount);
            _mint(msg.sender, tokenId, 1, "");
        }

        dogeChampionsTournament.decreaseConsumableReward(amount, msg.sender);

        setApprovalForAll(marketplaceAddress, true);
    }

    function migrationMint(uint256 tokenId, address user, uint256 amount) public onlyOwner
    {
        require(!isMigrationOver, "This function can only be called during V2 migration.");
        _mint(user, tokenId, amount, "");
    }

    /*
     * @author mints given premium consumable to user for a price
     */
    function premiumMint(uint256 tokenId, uint256 amount) public payable
    {
        require(tokenId > 2 && tokenId < 6, "There is no such premium consumable type.");
        require(msg.value == premiumPrice * amount, "Please send exact price.");

        _mint(msg.sender, tokenId, amount, "");

        payable(owner()).transfer(msg.value);

        setApprovalForAll(marketplaceAddress, true);
    }

    /*
     * @author mints given bundle
     */
    function bundleMint(uint256 tokenId, uint256 bundleId) public payable
    {
        require(areBundlesAvailable == true, "Bundle sales are closed.");
        require(tokenId > 2 && tokenId < 6, "There is no such premium consumable type.");
        require(bundleId >= 0 && bundleId < 5, "There are only 5 bundles.");
        require(msg.value == bundleIdToPrice[bundleId], "Please send exact price.");

        _mint(msg.sender, tokenId, bundleIdToBundle[bundleId], "");

        payable(owner()).transfer(msg.value);

        setApprovalForAll(marketplaceAddress, true);
    }

    /*
     * @author mints consume frenzy event reward
     */
    function consumeFrenzyEventMint(uint256 premiumTokenId) public
    {
        require(isConsumeFrenzyEventActive == true, "Consume frenzy event is not active.");
        require(premiumTokenId >= 3 && premiumTokenId < 6, "There is no such premium type.");
        require(userToUsedConsumable[activeConsumeFrenzyEventId][msg.sender] >= consumeFrenzyEventEntranceCount, "Not enough consumables.");

        _mint(msg.sender, premiumTokenId, consumeFrenzyEventRewardCount, "");
        userToUsedConsumable[activeConsumeFrenzyEventId][msg.sender] = userToUsedConsumable[activeConsumeFrenzyEventId][msg.sender] - consumeFrenzyEventEntranceCount;
    }

    /*
     * @author mints premium consumable from premium event
     */
    function premiumEventMint(uint256 consumableId) public
    {
        require(isPremiumEventActive == true, "Premium event is not active.");
        require(consumableId >= 0 && consumableId < 3, "There is no such consumable type.");
        require(balanceOf(msg.sender, consumableId) >= premiumEventEntranceCount, "Not enough consumables.");

        _burn(msg.sender, consumableId, premiumEventEntranceCount);
        _mint(msg.sender, consumableId + 3, premiumEventRewardCount, "");
    }

    /*
     * @author mints consumable as rewards of DogeChampions playable content
     */
    function rewardMint(address walletAddress, uint256 amount, bool isPremium) public onlyDogeChampionsProtocols
    {
        if(isPremium)
        {
            _mint(walletAddress, calculateConsumableType(block.timestamp) + 3, amount, "");
        }
        else
        {
            _mint(walletAddress, calculateConsumableType(block.timestamp) + 3, amount, "");
        }
        
    }

    /*
     * @author burns consumable after user uses it onto a Doge Champion
     */
    function burn(uint256 tokenId, address walletAddress) public onlyDogeChampionsNFT
    {
        if(isConsumeFrenzyEventActive)
        {
            userToUsedConsumable[activeConsumeFrenzyEventId][walletAddress] = userToUsedConsumable[activeConsumeFrenzyEventId][walletAddress] + 1;
        }

        _burn(walletAddress, tokenId, 1);
    }

    /*
     * @author sets bundle availability
     */
    function setBundlesAvailability(bool isAvailable) public onlyOwner
    {
        areBundlesAvailable = isAvailable;
    }

    /*
     * @author sets consume frenzy event state
     */
    function setConsumeFrenzyEventState(bool isActive) public onlyOwner
    {
        require(isConsumeFrenzyEventActive != isActive, "State is the same.");
        isConsumeFrenzyEventActive = isActive;
        if(!isActive)
        {
            activeConsumeFrenzyEventId = activeConsumeFrenzyEventId + 1;
        }
    }

    /*
     * @author sets premium event state
     */
    function setPremiumEventState(bool isActive) public onlyOwner
    {
        isPremiumEventActive = isActive;
    }

    /*
     * @author sets consume frenzy event data
     */
    function setConsumeFrenzyEventData(uint256 entranceCount, uint256 rewardCount) public onlyOwner
    {
        consumeFrenzyEventEntranceCount = entranceCount;
        consumeFrenzyEventRewardCount = rewardCount;
    }

    /*
     * @author sets premium event data
     */
    function setPremiumEventData(uint256 entranceCount, uint256 rewardCount) public onlyOwner
    {
        premiumEventEntranceCount = entranceCount;
        premiumEventRewardCount = rewardCount;
    }

    /*
     * @author sets bundle amount and price of given bundle Id. Send bundle price x1000 of the value.
     */
    function setBundleDetails(uint256 bundleId, uint256 bundleAmount, uint256 bundlePrice) public onlyOwner
    {
        require(bundleId >= 0 && bundleId < 5, "There are only 5 bundles.");
        bundleIdToBundle[bundleId] = bundleAmount;
        bundleIdToBundle[bundleId] = bundlePrice * (0.001 ether);
    }

    /*
     * @author sets isMigrationOver flag to false to cancel usage of migration mint function
     */
    function finalizeMigration() public onlyOwner
    {
        require(!isMigrationOver, "Migration mint flag can be set only once to false.");
        isMigrationOver = true;
    }

    /*
     * @author returns user progress for consume frenzy event
     */
    function getConsumeFrenzyEventProgress() public view returns(uint256 progress, uint256)
    {
        return (userToUsedConsumable[activeConsumeFrenzyEventId][msg.sender], consumeFrenzyEventEntranceCount);
    }

    /*
     * @author helper function to determine consumable type randomly
     */
    function calculateConsumableType(uint256 nonce) internal view returns(uint256)
    {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 3;
    }
}