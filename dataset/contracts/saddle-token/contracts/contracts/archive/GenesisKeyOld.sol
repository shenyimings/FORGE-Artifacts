// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "../erc721a/ERC721AUpgradeable.sol";
import "../interface/IGenesisKey.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

error PausedTransfer();
error MaxSupply();
error LockUpUnavailable();

interface IGkTeamClaim {
    function addTokenId(uint256 newTokenId) external;
}

contract GenesisKeyOld is Initializable, ERC721AUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, IGenesisKey {
    using SafeMathUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    // 2^128 is more than enough to store unix timestamp
    struct LockupInfo {
        uint128 totalLockup; // total lockup of this GK
        uint128 currentLockup; // unlocked when currentLock is 0
    }

    /* An ECDSA signature. */
    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    address public owner;
    uint96 public publicSaleDurationSeconds; // length of public sale in seconds

    address public multiSig;
    uint96 public initialEthPrice; // initial price of genesis keys in Weth

    address public genesisKeyMerkle;
    uint96 public finalEthPrice; // final price of genesis keys in Weth

    address public gkTeamClaimContract;
    uint96 public publicSaleStartSecond; // second public sale starts

    address public signerAddress;
    bool public startPublicSale; // global state indicator if public sale is happening
    bool public pausedTransfer; // true transfers are paused
    bool public randomClaimBool; // true if random claim is enabled for team (only used for testing consistency)
    bool public lockupBoolean; // true if GK holders can lockup, false if not
    uint64 public remainingTeamAdvisorGrant; // Genesis Keys reserved for team / advisors / grants

    mapping(bytes32 => bool) public cancelledOrFinalized; // used hash
    mapping(address => bool) public whitelistedTransfer; // Whitelisted transfer (true / false)
    mapping(uint256 => LockupInfo) private _genesisKeyLockUp;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public latestClaimTokenId;

    event ClaimedGenesisKey(address indexed _user, uint256 _amount, uint256 _blockNum, bool _whitelist);

    modifier onlyOwner() {
        require(msg.sender == owner, "GEN_KEY: !AUTH");
        _;
    }

    function initialize(
        string memory name,
        string memory symbol,
        address _multiSig,
        uint256 _auctionSeconds,
        bool _randomClaimBool,
        string memory baseURI
    ) public initializer {
        __ReentrancyGuard_init();
        __ERC721A_init(name, symbol, baseURI);
        __UUPSUpgradeable_init();

        startPublicSale = false;
        publicSaleDurationSeconds = uint96(_auctionSeconds);
        owner = msg.sender;
        multiSig = _multiSig;
        remainingTeamAdvisorGrant = 250; // 250 genesis keys allocated
        randomClaimBool = _randomClaimBool;
        signerAddress = 0x9EfcD5075cDfB7f58C26e3fB3F22Bb498C6E3174;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // governance functions =================================================================
    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function currentXP(uint256 tokenId)
        external
        view
        returns (
            bool locked,
            uint256 current,
            uint256 total
        )
    {
        uint256 start = _genesisKeyLockUp[tokenId].currentLockup;
        if (start != 0) {
            locked = true;
            current = block.timestamp - start;
        }
        total = current + _genesisKeyLockUp[tokenId].totalLockup;
    }

    function toggleLockup(uint256 tokenId) internal {
        require(msg.sender == ownerOf(tokenId));
        uint256 start = _genesisKeyLockUp[tokenId].currentLockup;
        if (start == 0) {
            if (!lockupBoolean) revert LockUpUnavailable();
            _genesisKeyLockUp[tokenId].currentLockup = uint128(block.timestamp);
        } else {
            _genesisKeyLockUp[tokenId].totalLockup += uint128(block.timestamp - start);
            _genesisKeyLockUp[tokenId].currentLockup = 0;
        }
    }

    function toggleLockup(uint256[] calldata tokenIds) external {
        uint256 n = tokenIds.length;
        for (uint256 i = 0; i < n; ++i) {
            toggleLockup(tokenIds[i]);
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        if (_genesisKeyLockUp[tokenId].currentLockup != 0) revert PausedTransfer();

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        if (_genesisKeyLockUp[tokenId].currentLockup != 0) revert PausedTransfer();

        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        if (_genesisKeyLockUp[tokenId].currentLockup != 0) revert PausedTransfer();

        _transfer(from, to, tokenId);
        if (isContract(to) && !_checkContractOnERC721Received(from, to, tokenId, _data)) {
            revert TransferToNonERC721ReceiverImplementer();
        }
    }

    function setMultiSig(address _newMS) external onlyOwner {
        multiSig = _newMS;
    }

    function toggleLockupBoolean() external onlyOwner {
        lockupBoolean = !lockupBoolean;
    }

    function setGenesisKeyMerkle(address _newMK) external onlyOwner {
        genesisKeyMerkle = _newMK;
    }

    function setPublicSaleDuration(uint96 _seconds) external onlyOwner {
        publicSaleDurationSeconds = _seconds;
    }

    function setWhitelist(address _address, bool _val) external onlyOwner {
        whitelistedTransfer[_address] = _val;
    }

    function setSigner(address _signer) external onlyOwner {
        signerAddress = _signer;
    }

    // initial weth price is the high price (starting point)
    // final weth price is the lowest floor price we allow
    // num keys for sale is total keys allowed to mint
    function initializePublicSale(uint96 _initialEthPrice, uint96 _finalEthPrice) external onlyOwner {
        require(!startPublicSale, "GEN_KEY: sale already initialized");
        initialEthPrice = _initialEthPrice;
        finalEthPrice = _finalEthPrice;
        publicSaleStartSecond = uint96(block.timestamp);
        startPublicSale = true;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    // =========POST WHITELIST CLAIM KEY ==========================================================================
    /**
     @notice allows winning keys to be self-minted by winners
    */
    function claimKey(address recipient, uint256 _eth) external payable override nonReentrant returns (bool) {
        // checks
        require(msg.sender == genesisKeyMerkle);
        require(!startPublicSale, "GEN_KEY: only during blind");
        require(msg.value >= _eth);
        if (remainingTeamAdvisorGrant + totalSupply() == MAX_SUPPLY) revert MaxSupply();

        // effects
        // interactions
        _mint(recipient, 1, "", false);
        randomTeamGrant(recipient);

        if (msg.value > _eth) {
            safeTransferETH(recipient, msg.value - _eth);
        }

        safeTransferETH(multiSig, address(this).balance);

        emit ClaimedGenesisKey(recipient, _eth, block.number, true);

        return true;
    }

    // pseudo-randomly assign a team to a key
    function randomTeamGrant(address _recipient) private {
        if (
            remainingTeamAdvisorGrant != 0 &&
            (uint256(uint160(_recipient)) + block.timestamp) % 5 == 0 &&
            randomClaimBool
        ) {
            remainingTeamAdvisorGrant -= 1;

            _mint(gkTeamClaimContract, 1, "", false);
            IGkTeamClaim(gkTeamClaimContract).addTokenId(totalSupply());
            emit ClaimedGenesisKey(gkTeamClaimContract, 0, block.number, false);
        }
    }

    function setGkTeamClaim(address _gkTeamClaimContract) external onlyOwner {
        gkTeamClaimContract = _gkTeamClaimContract;
    }

    /**
     @notice sends grant key to end user for team / advisors / grants
    */
    function claimGrantKey(uint256 amount) external onlyOwner {
        require(amount != 0);
        require(remainingTeamAdvisorGrant >= amount);
        if (remainingTeamAdvisorGrant + totalSupply() == MAX_SUPPLY) revert MaxSupply();

        remainingTeamAdvisorGrant -= uint64(amount);
        _mint(gkTeamClaimContract, amount, "", false);

        for (uint256 i = 0; i < amount; i++) {
            emit ClaimedGenesisKey(gkTeamClaimContract, 0, block.number, false);
        }
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "STE");
    }

    // helper function for transferring eth from the public auction to MS
    function transferETH() external onlyOwner {
        safeTransferETH(multiSig, address(this).balance);
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    // ========= PUBLIC SALE =================================================================
    // external function for public sale of genesis keys
    function publicExecuteBid(uint256 amount) external payable nonReentrant {
        // checks
        require(startPublicSale, "GEN_KEY: invalid time");
        require(!isContract(msg.sender), "GEN_KEY: !CONTRACT");
        require(amount != 0 && amount <= 100, "GEN_KEY: !AMOUNT");
        if (amount + remainingTeamAdvisorGrant + totalSupply() > 5000) revert MaxSupply();
        uint256 currPrice = getCurrentPrice();
        uint256 totalETH = currPrice * amount;
        require(msg.value >= totalETH, "GEN_KEY: INSUFFICIENT FUNDS");

        // effects
        // interactions
        if (msg.value > totalETH) {
            safeTransferETH(msg.sender, msg.value - totalETH);
        }

        safeTransferETH(multiSig, address(this).balance);
        _mint(msg.sender, amount, "", false);
        randomTeamGrant(msg.sender);

        for (uint256 i = 0; i < amount; i++) {
            emit ClaimedGenesisKey(msg.sender, currPrice, block.number, false);
        }
    }

    function mintLeftOver(uint256 quantityToClaim, uint256 quantityToTreasury) external onlyOwner {
        require(quantityToClaim != 0 && quantityToTreasury != 0);
        require(remainingTeamAdvisorGrant == 0);
        require(quantityToClaim + quantityToTreasury + remainingTeamAdvisorGrant + totalSupply() == MAX_SUPPLY);

        latestClaimTokenId = totalSupply();

        _mint(address(this), quantityToClaim, "", false);

        _mint(multiSig, quantityToTreasury, "", false);

        // for (uint256 i = 0; i < quantityToClaim + quantityToTreasury; i++) {
        //     emit ClaimedGenesisKey(msg.sender, 0, block.number, false);
        // }
    }

    function publicBuyKey() external payable nonReentrant {
        // checks
        require(startPublicSale, "GEN_KEY: invalid time");
        require(!isContract(msg.sender), "GEN_KEY: !CONTRACT");
        if (totalSupply() != MAX_SUPPLY) revert MaxSupply();
        if (latestClaimTokenId == 5000) revert MaxSupply();

        uint256 currPrice = getCurrentPrice();
        require(msg.value >= currPrice, "GEN_KEY: INSUFFICIENT FUNDS");

        // effects
        latestClaimTokenId += 1;

        // interactions
        if (msg.value > currPrice) {
            safeTransferETH(msg.sender, msg.value - currPrice);
        }

        safeTransferETH(multiSig, address(this).balance);
        _adminTransfer(address(this), msg.sender, latestClaimTokenId);
    }

    // public function for returning the current price
    function getCurrentPrice() public view returns (uint256) {
        require(startPublicSale, "GEN_KEY: invalid time");
        uint256 secondsPassed = 0;

        secondsPassed = block.timestamp - publicSaleStartSecond;

        if (secondsPassed >= publicSaleDurationSeconds) {
            return finalEthPrice;
        } else {
            uint256 totalPriceChange = initialEthPrice - finalEthPrice;
            uint256 currentPriceChange = totalPriceChange.mul(secondsPassed).div(publicSaleDurationSeconds);
            uint256 currentPrice = initialEthPrice - currentPriceChange;

            return currentPrice;
        }
    }
}
