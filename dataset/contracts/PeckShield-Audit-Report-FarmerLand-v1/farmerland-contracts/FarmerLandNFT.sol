pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./WHEAT.sol";

contract FarmerLandNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for WHEAT;

    mapping(address => uint) public userRoostingsCount;

    uint public immutable MAX_ELEMENTS;
    uint public maticPrice = 0 * 1e18;
    uint public wheatPrice = 3 * 1e18;

    WHEAT public immutable wheatToken;

    mapping(address => bool) public admins;

    address public constant founder = 0xC43f13A64fd351C8846660B5D02dB344829859b8;

    bool public paused = true;
    uint public startTime;

    uint public constant MAX_CONCURRENT_MINT = 50;
    uint public immutable MAX_LEVEL;
    uint public constant MAX_ABILITY = 999e4;
    uint public immutable ABILITY_SCALAR;

    mapping(uint => uint) private level;
    mapping(uint => uint) private ability;

    uint public immutable nftType;

    string public baseTokenURI;

    // Timers for how long an nftId has been roosted
    mapping(uint => uint) public foreverRoostingTimer;
    mapping(uint => uint) public startOfCurrentRoosting;

    // Whitelist for people to get one free mint (promo)
    mapping(address => bool) public freeMintWhitelist;

    event AbilitySet(uint tokenId, uint oldAbility, uint newAbility);
    event LevelSet(uint tokenId, uint oldLevel, uint newLevel);
    event WithdrawGas(address destination, uint gasBalance);
    event WithdrawWHEAT(address destination, uint wheatBalance);
    event AddToWhiteList(uint numberOfAllocations);
    event BaseURISet(string oldURI, string newURI);

    event Paused(bool currentPausedStatus);
    event StartTimeChanged(uint newStartTime);
    event WHEATPriceSet(uint price);
    event MATICPriceSet(uint price);
    event AdminSet(address admin, bool value);
    event NFTRoosted(uint indexed id);
    event NFTUnRoosted(uint indexed id);
    event CreateFarmerLandNFT(uint indexed id);
    constructor(uint  _startTime, uint _nftType, uint _MAX_ELEMENTS,  uint _MAX_LEVEL, uint _ABILITY_SCALAR, WHEAT _WHEAT, string memory name1, string memory name2) ERC721(name1, name2) {
        require(_MAX_ELEMENTS%2 == 0, "max elements must be even");
        require(_MAX_LEVEL <= 200, "_ABILITY_SCALAR out of range");
        require(_ABILITY_SCALAR > 0 && _ABILITY_SCALAR <= 10, "_ABILITY_SCALAR out of range");

        MAX_ELEMENTS = _MAX_ELEMENTS;
        MAX_LEVEL =_MAX_LEVEL;
        ABILITY_SCALAR = _ABILITY_SCALAR;

        wheatToken = _WHEAT;

        startTime = _startTime;
        nftType = _nftType;

        admins[founder] = true;
        admins[msg.sender] = true;
    }

    mapping(uint256 => uint256) private _tokenIdsCache;

    function availableSupply() public view returns (uint) {
        return MAX_ELEMENTS - totalSupply();
    }
    function _getNextRandomNumber() private returns (uint256 index) {
        uint _availableSupply = availableSupply();
        require(_availableSupply > 0, "Invalid _remaining");

        uint256 i = (MAX_ELEMENTS + uint(keccak256(abi.encode(block.timestamp, tx.origin, blockhash(block.number-1))))) %
            _availableSupply;

        // if there's a cache at _tokenIdsCache[i] then use it
        // otherwise use i itself
        index = _tokenIdsCache[i] == 0 ? i : _tokenIdsCache[i];

        // grab a number from the tail
        _tokenIdsCache[i] = _tokenIdsCache[_availableSupply - 1] == 0
            ? _availableSupply - 1
            : _tokenIdsCache[_availableSupply - 1];
    }

    function getUsersNumberOfRoostings(address user) external view returns (uint) {
        return userRoostingsCount[user];
    }

    function getAbility(uint tokenId) external view returns (uint) {
        return ability[tokenId];
    }

    function setAbility(uint tokenId, uint _ability) external {
        require(admins[msg.sender], "sender not admin!");
        require(_ability <= MAX_ABILITY, "ability too high!");

        uint oldAbility = ability[tokenId];

        ability[tokenId] = _ability;

        emit AbilitySet(tokenId, oldAbility, _ability);
    }

    function getLevel(uint tokenId) external view returns (uint) {
        return level[tokenId];
    }

    function setLevel(uint tokenId, uint _level) external {
        require(admins[msg.sender], "sender not admin!");
        require(_level <= MAX_LEVEL, "level too high!");

        uint oldLevel = level[tokenId];

        level[tokenId] = _level;

         emit LevelSet(tokenId, oldLevel, _level);
    }

    function mint(address _to, uint _count) external payable nonReentrant {
        require(!paused, "Minting is paused!");
        require(startTime < block.timestamp, "Minting not started yet!");
        require(admins[msg.sender] || _count <= MAX_CONCURRENT_MINT, "Can only mint 50!");

        uint total = totalSupply();
        require(total + _count <= MAX_ELEMENTS, "Max limit");

        if (!freeMintWhitelist[msg.sender]) {
            require(msg.value >= getMATICPrice(_count) ||
                    admins[msg.sender], "Value below price");
            if (!admins[msg.sender])
                wheatToken.safeTransferFrom(msg.sender, address(this), getWHEATPrice(_count));
        } else {
            require(msg.value >= getMATICPrice(_count - 1) ||
                    admins[msg.sender], "Value below price");
            if (!admins[msg.sender])
                wheatToken.safeTransferFrom(msg.sender, address(this), getWHEATPrice(_count - 1));
            freeMintWhitelist[msg.sender] = false;
        }

        for (uint i = 0; i < _count; i++) {
            _mintAnElement(_to);
        }
    }
    function _mintAnElement(address _to) private {
        uint id = _getNextRandomNumber() + 1;

        // intentionally predictable
        uint abilityRNG = uint(keccak256(abi.encode(id * MAX_ELEMENTS))) % 10;

        if (abilityRNG == 0) {
            ability[id] = 4e4; // 10% probability
        } else if (abilityRNG <= 3) {
            ability[id] = 3e4; // 30% probability
        } else if (abilityRNG <= 6) {
            ability[id] = 2e4; // 30% probability
        } else {
            ability[id] = 1e4; // 30% probability
        }

        ability[id] = ability[id] * ABILITY_SCALAR;

        emit CreateFarmerLandNFT(id);

        _mint(_to, id);
    }
    function getMATICPrice(uint _count) public view returns (uint) {
        return maticPrice * _count;
    }
    function getWHEATPrice(uint _count) public view returns (uint) {
        return wheatPrice * _count;
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
    function setBaseURI(string memory baseURI) external onlyOwner {
        emit BaseURISet(baseTokenURI, baseURI);

        baseTokenURI = baseURI;
    }
    function withdrawGas() public payable onlyOwner {
        uint gasBalance = address(this).balance;
        require(gasBalance > 0, "zero balance");

        _withdraw(founder, gasBalance);

        emit WithdrawGas(founder, gasBalance);
    }

    function withdrawWHEAT() public onlyOwner {
        uint wheatBalance = wheatToken.balanceOf(address(this));
        require(wheatBalance > 0, "zero balance");

        wheatToken.safeTransfer(founder, wheatBalance);

        emit WithdrawWHEAT(founder, wheatBalance);
    }

    function walletOfOwner(address _owner, uint startIndex, uint count) external view returns (uint[] memory) {
        uint tokenCount = balanceOf(_owner);

        uint[] memory tokensId = new uint[](tokenCount);
        for (uint i = startIndex; i < tokenCount && i - startIndex < count; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }
    function _withdraw(address _address, uint _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }
    /// @dev overrides transfer function to enable roosting!
    function _transfer(address from, address to, uint tokenId) internal override {
        if (isNftIdRoosting(tokenId)) {
            foreverRoostingTimer[tokenId]+= block.timestamp - startOfCurrentRoosting[tokenId];
            startOfCurrentRoosting[tokenId] = 0;

            userRoostingsCount[from]--;

            emit NFTUnRoosted(tokenId);
        }

        super._transfer( from, to, tokenId );
    }
    function isNftIdRoosting(uint nftId) public view returns (bool) {
        return startOfCurrentRoosting[nftId] > 0;
    }
    function isNftIdRoostingWithOwner(address owner, uint nftId) external view returns (bool) {
        return ownerOf(nftId) == owner && startOfCurrentRoosting[nftId] > 0;
    }
    function roostNftId(uint nftId) external {
        require(ownerOf(nftId) == msg.sender, "owner of NFT isn't sender!");
        require(nftId <= MAX_ELEMENTS, "invalid NFTId!");
        require(startOfCurrentRoosting[nftId] == 0, "nft is aready roosting!");

        startOfCurrentRoosting[nftId] = block.timestamp;

        userRoostingsCount[msg.sender]++;

        emit NFTRoosted(nftId);
    }
    function unroostNftId(uint nftId) public {
        require(ownerOf(nftId) == msg.sender, "owner of NFT isn't sender!");
        require(nftId <= MAX_ELEMENTS, "invalid NFTId!");
        require(startOfCurrentRoosting[nftId] > 0, "nft isnt currently roosting!");

        foreverRoostingTimer[nftId]+= block.timestamp - startOfCurrentRoosting[nftId];
        startOfCurrentRoosting[nftId] = 0;

        userRoostingsCount[msg.sender]--;

        emit NFTUnRoosted(nftId);
    }
    function addToWhiteList(address[] calldata participants) external onlyOwner {
        for (uint i = 0;i<participants.length;i++) {
            freeMintWhitelist[participants[i]] = true;
        }

        emit AddToWhiteList(participants.length);
    }
    function setMATICPrice(uint _newPrice) public onlyOwner {
        maticPrice = _newPrice;

        emit MATICPriceSet(maticPrice);
    }
    function setWHEATPrice(uint _newPrice) public onlyOwner {
        wheatPrice = _newPrice;

        emit WHEATPriceSet(wheatPrice);
    }
   function pause() external onlyOwner {
        paused = !paused;

        emit Paused(paused);
    }
   function setStartTime(uint _newStartTime) external onlyOwner {
        require(startTime == 0 || block.timestamp < startTime, "Minting has already started!");
        require(_newStartTime > startTime, "new start time must be in future!");
        startTime = _newStartTime;

        emit StartTimeChanged(_newStartTime);
    }
    function setAdmins(address _newAdmin, bool status) public onlyOwner {
        admins[_newAdmin] = status;

        emit AdminSet(_newAdmin, status);
    }
}