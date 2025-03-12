// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../tokens/ERC721/NftTokenBase.sol";
import "./NftTokenStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NftTokenCrowdsale is
    AccessControl,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    NftTokenBase public token;
    NftTokenBase public tokenToyo;
    NftTokenBase public tokenBox;
    NftTokenBase public tokenAirdrop;
    NftTokenStorage private tokenStorage;

    address public vault;

    bool public isWhitelistByBalanceEnabled;

    /**
     * Event for token purchase logging
     * @param spender who paid for the tokens
     * @param beneficiary who got the tokens
     * @param typeId of the token sold
     * @param totalSupply of the token type included the purchase that trigger the event
     * @param tokenId of the token type sold
     * @param value in wei involved in the purchase
     */
    event TokenPurchased(
        address indexed spender,
        address indexed beneficiary,
        uint256 indexed typeId,
        uint256 totalSupply,
        uint256 tokenId,
        uint256 value
    );

    event SoldOut(uint256 indexed typeId);

    event TokenPaused(uint256 indexed typeId, address changer);

    event TokenUnpaused(uint256 indexed typeId, address changer);

    event MaxSupplyChanged(uint256 indexed typeId, address changer, uint256 newValue);

    event PurchaseCapChanged(uint256 indexed typeId, address changer, uint256 newValue);

    event RateChanged(uint256 indexed typeId, address changer, uint256 newValue);

    event WhitelistChanged(address changer, bool newValue);
    
    event WhitelistAdded(address changer, address added);

    event WhitelistRemoved(address changer, address removed);

    event BlacklistChanged(address changer, bool newValue);

    event BlacklistAdded(address changer, address added);

    event BlacklistRemoved(address changer, address removed);

    event CoolDownChanged(address changer, uint256 newValue);

    event RoyaltiesRecipientAddressChanged(address changer, address newValue);

    event PercentageBasisPointsChanged(address changer, uint96 newValue);

    event TokenTypeAdded(address changer, uint256 newValue);

    event VaultChanged(address changer, address newValue);
    
    event NftTokenChanged(address changer, address newValue);

    event NftTokenToyoChanged(address changer, address newValue);

    event NftTokenBoxChanged(address changer, address newValue);

    event NftTokenAirdropChanged(address changer, address newValue);

    event NftStorageChanged(address changer, address newValue);

    event WhitelistByBalanceChanged(address changer, bool newValue);

    /**
     * @param _vault Address where collected funds will be forwarded to
     * @param _token Address of the token being sold
     * @param _tokenAirdrop Address of the token being airdropped
     * @param _storage Address of the eternal storage contract
     */
    constructor(
        address payable _vault,
        NftTokenBase _token,
        NftTokenBase _tokenToyo,
        NftTokenBase _tokenBox,
        NftTokenBase _tokenAirdrop,
        NftTokenStorage _storage
    ) isValidAddress(_vault) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);

        token = _token;
        tokenToyo = _tokenToyo;
        tokenBox = _tokenBox;
        tokenAirdrop = _tokenAirdrop;
        tokenStorage = _storage;
        vault = _vault;
        
    }

    function initialize(
        uint256 _coolDownSeconds,
        address payable _royaltiesRecipientAddress,
        uint96 _percentageBasisPoints
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        setCoolDown(_coolDownSeconds);
        setRoyaltiesRecipientAddress(_royaltiesRecipientAddress);
        setPercentageBasisPoints(_percentageBasisPoints);
    }

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------
    /**
     * @param _spender Address performing the token purchase
     * @param _typeId of the token being sold
     * @param _quantity of the token being sold
     */
    function buyTokens(
        address _spender,
        uint256 _typeId,
        uint256 _quantity
    )
        public
        payable
        nonReentrant
        isValidTokenType(_typeId)
        isValidAddress(_spender)
        isValidQuantity(_quantity)
    {
        uint256 _wei = msg.value;

        _preValidatePurchase(_spender, _wei, _typeId, _quantity);

        _forwardFunds();

        for (uint256 i = 0; i < _quantity; i++) {
            _processPurchase(_spender, _typeId, tokenBox);
        }

        _postValidatePurchase(_spender, _typeId, _wei);
    }

    /**
     * @dev Returns the amount contributed so far by a sepecific user.
     * @param _account Address of contributor
     * @return User contribution so far
     */
    function getUserContribution(address _account)
        public
        view
        returns (uint256)
    {
        return tokenStorage.getUserContribution(_account);
    }

    // -----------------------------------------
    // Public view
    // -----------------------------------------

    function getTotalMinted() public view returns (uint256) {
        return tokenStorage.getTotalMinted();
    }

    function getLastTypeId() public view returns (uint256) {
        return tokenStorage.getLastTypeId();
    }

    function getTotalSupply(uint256 _typeId)
        public
        view
        isValidTokenType(_typeId)
        returns (uint256)
    {
        return tokenStorage.getTotalSupply(_typeId);
    }

    function getRate(uint256 _typeId)
        public
        view
        isValidTokenType(_typeId)
        returns (uint256)
    {
        return tokenStorage.getRate(_typeId);
    }

    function getMaxSupply(uint256 _typeId)
        public
        view
        isValidTokenType(_typeId)
        returns (uint256)
    {
        return tokenStorage.getMaxSupply(_typeId);
    }

    function getPurchaseCap(uint256 _typeId)
        public
        view
        isValidTokenType(_typeId)
        returns (uint256)
    {
        return tokenStorage.getPurchaseCap(_typeId);
    }

    function getLastPurchaseTime(address _spender)
        public
        view
        isValidAddress(_spender)
        returns (uint256)
    {
        return tokenStorage.getLastPurchaseTime(_spender);
    }

    function weiRaised() public view returns (uint256) {
        return tokenStorage.weiRaised();
    }

    function getRoyaltiesRecipientAddress()
        public
        view
        returns (address payable)
    {
        return tokenStorage.royaltiesRecipientAddress();
    }

    function getPercentageBasisPoints() public view returns (uint96) {
        return tokenStorage.percentageBasisPoints();
    }

    function getCoolDownSeconds() public view returns (uint256) {
        return tokenStorage.coolDowmSeconds();
    }

    function isPaused(uint256 _typeId)
        public
        view
        isValidTokenType(_typeId)
        returns (bool)
    {
        return _isPaused(_typeId);
    }

    function isWhitelisted(address _account)
        public
        view
        isValidAddress(_account)
        returns (bool)
    {
        return _isWhitelisted(_account);
    }

    function isBlacklisted(address _account)
        public
        view
        isValidAddress(_account)
        returns (bool)
    {
        return _isBlacklisted(_account);
    }

    function isGraylisted(address _account)
        public
        view
        isValidAddress(_account)
        returns (bool)
    {
        return _isGraylisted(_account);
    }

    function balanceOf(address _owner, uint256 _typeId)
        public
        view
        isValidAddress(_owner)
        isValidTokenType(_typeId)
        returns (uint256)
    {
        return tokenStorage.balanceOf(_owner, _typeId);
    }


    // -----------------------------------------
    // Public onlyMinter
    // -----------------------------------------

    function sendAirdrop(
        address _spender,
        uint256 _typeId,
        uint256 _quantity
    )
        public onlyRole(MINTER_ROLE)
        nonReentrant
        isValidTokenType(_typeId)
        isValidAddress(_spender)
        isValidQuantity(_quantity)
     {
        for (uint256 i = 0; i < _quantity; i++) {
            _processPurchase(_spender, _typeId, tokenAirdrop);
        }
    }

    // -----------------------------------------
    // Public onlyAdmin
    // -----------------------------------------

    function addTokenType(
        string memory _metadata,
        uint256 _rate,
        uint256 _maxSupply,
        uint256 _purchaseCap,
        bool _paused
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenStorage.incrementTypeId();
        uint256 newTypeId = tokenStorage.getLastTypeId();

        tokenStorage.setMetadata(newTypeId, _metadata);
        tokenStorage.setRate(newTypeId, _rate);
        tokenStorage.setMaxSupply(newTypeId, _maxSupply);
        tokenStorage.setPurchaseCap(newTypeId, _purchaseCap);
        tokenStorage.setPause(newTypeId, _paused);

        emit TokenTypeAdded(_msgSender(), newTypeId);
    }

    function setMetadata(uint256 _typeId, string memory _metadata)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        isValidTokenType(_typeId)
    {
        tokenStorage.setMetadata(_typeId, _metadata);
    }

    function setRate(uint256 _typeId, uint256 _rate)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        isValidTokenType(_typeId)
    {
        require(_rate > 0);

        tokenStorage.setRate(_typeId, _rate);

        emit RateChanged(_typeId, _msgSender(), _rate);
    }

    function setWhitelist(bool _enable) 
        public 
        onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenStorage.setWhitelist(_enable);

        emit WhitelistChanged(_msgSender(), _enable);
    }

    function addToWhitelist(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenStorage.addToWhitelist(_account);

        emit WhitelistAdded(_msgSender(), _account);
    }

    function removeFromWhitelist(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenStorage.removeFromWhitelist(_account);

        emit WhitelistRemoved(_msgSender(), _account);
    }

    function setBlacklist(bool _enable) 
        public 
        onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenStorage.setBlacklist(_enable);

        emit BlacklistChanged(_msgSender(), _enable);
    }

    function addToBlacklist(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        isValidAddress(_account)
    {
        tokenStorage.addToBlacklist(_account);

        emit BlacklistAdded(_msgSender(), _account);
    }

    function removeFromBlacklist(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        isValidAddress(_account)
    {
        tokenStorage.removeFromBlacklist(_account);

        emit BlacklistRemoved(_msgSender(), _account);
    }

    function setMaxSupply(uint256 _typeId, uint256 _maxSupply)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        isValidTokenType(_typeId)
    {
        require(_maxSupply > 0);

        tokenStorage.setMaxSupply(_typeId, _maxSupply);

        emit MaxSupplyChanged(_typeId, _msgSender(), _maxSupply);
    }

    function setCoolDown(uint256 _seconds) 
        public 
        onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenStorage.setCoolDown(_seconds);

        emit CoolDownChanged(_msgSender(), _seconds);
    }

    function setPurchaseCap(uint256 _typeId, uint256 _cap)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        isValidTokenType(_typeId)
    {
        require(_cap > 0);

        tokenStorage.setPurchaseCap(_typeId, _cap);

        emit PurchaseCapChanged(_typeId, _msgSender(), _cap);
    }

    function setRoyaltiesRecipientAddress(address payable _to)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        isValidAddress(_to)
    {
        tokenStorage.setRoyaltiesRecipientAddress(_to);

        emit RoyaltiesRecipientAddressChanged(_msgSender(), _to);
    }

    function setPercentageBasisPoints(uint96 _percentage)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenStorage.setPercentageBasisPoints(_percentage);

        emit PercentageBasisPointsChanged(_msgSender(), _percentage);
    }

    function setWhitelistByBalance(bool _enable) 
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isWhitelistByBalanceEnabled = _enable;

        emit WhitelistByBalanceChanged(_msgSender(), _enable);
    }

    function setVault(address _address)
        public
        onlyOwner
        isValidAddress(_address)
    {
        vault = _address;

        emit VaultChanged(_msgSender(), _address);
    }

    function setToken(NftTokenBase _address)
        public
        onlyOwner
    {
        token = _address;

        emit NftTokenChanged(_msgSender(), address(_address));
    }

    function setTokenToyo(NftTokenBase _address)
        public
        onlyOwner
    {
        tokenToyo = _address;

        emit NftTokenToyoChanged(_msgSender(), address(_address));
    }


    function setTokenBox(NftTokenBase _address)
        public
        onlyOwner
    {
        tokenBox = _address;

        emit NftTokenBoxChanged(_msgSender(), address(_address));
    }

    function setTokenAirdrop(NftTokenBase _address)
        public
        onlyOwner
    {
        tokenAirdrop = _address;

        emit NftTokenAirdropChanged(_msgSender(), address(_address));
    }

    function setNftStorage(NftTokenStorage _address)
        public
        onlyOwner
    {
        tokenStorage = _address;

        emit NftStorageChanged(_msgSender(), address(_address));
    }

    // -----------------------------------------
    // Public onlyPauser
    // -----------------------------------------

    function pauseAll() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpauseAll() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function pause(uint256 _typeId)
        public
        onlyRole(PAUSER_ROLE)
        isValidTokenType(_typeId)
    {
        tokenStorage.setPause(_typeId, true);
        emit TokenPaused(_typeId, _msgSender());
    }

    function unpause(uint256 _typeId)
        public
        onlyRole(PAUSER_ROLE)
        isValidTokenType(_typeId)
    {
        tokenStorage.setPause(_typeId, false);
        emit TokenUnpaused(_typeId, _msgSender());
    }

    // -----------------------------------------
    // Internal
    // -----------------------------------------

    function _tokenTypeExists(uint256 _typeId) internal view returns (bool) {
        return bytes(tokenStorage.getMetadata(_typeId)).length != 0;
    }

    function _hasExactWei(
        uint256 _wei,
        uint256 _typeId,
        uint256 _quantity
    ) internal view returns (bool) {
        uint256 total = tokenStorage.getRate(_typeId).mul(_quantity);
        return (total == _wei);
    }

    function _hasEnoughQuantity(uint256 _typeId, uint256 _quantity)
        internal
        view
        returns (bool)
    {
        uint256 _maxSupply = getMaxSupply(_typeId);
        uint256 _totalSupply = getTotalSupply(_typeId);
        uint256 _available = _maxSupply.sub(_totalSupply);
        return (_available >= _quantity);
    }

    function _isWhitelisted(address _account) internal view returns (bool) {
        if(!tokenStorage.isWhitelistEnabled() && !isWhitelistByBalanceEnabled){
            return true;
        }

        bool hasWhitelist = false;

        if (tokenStorage.isWhitelistEnabled()) {
            hasWhitelist = tokenStorage.isWhitelisted(_account);
        }

        if (isWhitelistByBalanceEnabled && !hasWhitelist) {
            hasWhitelist = token.balanceOf(_account) > 0 || 
                           tokenToyo.balanceOf(_account) > 0 ||
                           tokenBox.balanceOf(_account) > 0;
        }
        return hasWhitelist;
    }

    function _isBlacklisted(address _account) internal view returns (bool) {
        if (tokenStorage.isBlacklistEnabled()) {
            return tokenStorage.isBlacklisted(_account);
        }

        return false;
    }

    function _isGraylisted(address _account) internal view returns (bool) {
        uint256 _coolDownSeconds = tokenStorage.coolDowmSeconds();

        if (_coolDownSeconds > 0) {
            uint256 _lastPurchaseTime = tokenStorage.getLastPurchaseTime(
                _account
            );

            if (_lastPurchaseTime > 0) {
                return _coolDownSeconds + _lastPurchaseTime > block.timestamp;
            }
        }
        return false;
    }

    function _isPaused(uint256 _typeId) internal view returns (bool) {
        return tokenStorage.isPaused(_typeId);
    }

    modifier isValidAddress(address _address) {
        _isValidAddress(_address);
        _;
    }

    modifier isValidTokenType(uint256 _typeId) {
        _isValidTokenType(_typeId);
        _;
    }

    modifier isValidQuantity(uint256 _quantity) {
        _isValidQuantity(_quantity);
        _;
    }

    function _isValidQuantity(uint256 _quantity) internal pure {
        require(_quantity > 0, "Quantity cannot be zero");
    }

    function _isValidAddress(address _address) internal pure {
        require(_address != address(0), "Invalid address");
    }

    function _isValidTokenType(uint256 _typeId) internal view {
        require(
            bytes(tokenStorage.getMetadata(_typeId)).length != 0,
            "Token type does not exist"
        );
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
     * @param _spender Address performing the token purchase
     * @param _wei Value in wei involved in the purchase
     * @param _typeId of the token type being sold
     * @param _quantity of the token type being sold
     */
    function _preValidatePurchase(
        address _spender,
        uint256 _wei,
        uint256 _typeId,
        uint256 _quantity
    ) internal {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            require(!_isBlacklisted(_spender), "You are blacklisted");
            require(_isWhitelisted(_spender), "You are not whitelisted");
            require(!_isGraylisted(_spender), "You are graylisted");

            require(_wei > 0, "Wei amount cannot be zero");
            require(
                _hasExactWei(_wei, _typeId, _quantity),
                "Value sent is below the price"
            );

            require(!paused(), "Paused");
            require(!_isPaused(_typeId), "Token type is paused");

            require(
                _hasEnoughQuantity(_typeId, _quantity),
                "Quantity exceeds max supply"
            );
            require(
                _quantity <= getPurchaseCap(_typeId),
                "Quantity exceeds purchase cap"
            );
        }

        uint256 _existingContribution = tokenStorage.getUserContribution(
            _spender
        );
        uint256 _newContribution = _existingContribution.add(_wei);
        tokenStorage.setUserContribution(_spender, _newContribution);
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
     * @param _spender Address performing the token purchase
     * @param _typeId of the token sold
     * @param _wei Value in wei involved in the purchase
     */
    function _postValidatePurchase(
        address _spender,
        uint256 _typeId,
        uint256 _wei
    ) internal {
        tokenStorage.setLastPurchaseTime(_spender, block.timestamp);

        uint256 raised = weiRaised().add(_wei);
        tokenStorage.setWeiRaised(raised);

        uint256 _totalSupply = getTotalSupply(_typeId);
        uint256 _maxSupply = getMaxSupply(_typeId);

        if (_totalSupply == _maxSupply) {
            emit SoldOut(_typeId);
        }
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _spender Address performing the token purchase
     * @param _typeId of the token type sold
     */
    function _deliverTokens(address _spender, uint256 _typeId, NftTokenBase _token) internal {
        // total of every token minted
        tokenStorage.incrementTokenId();

        uint256 newItemId = tokenStorage.getTotalMinted();

        string memory metadata = tokenStorage.getMetadata(_typeId);

        _token.mintWithRoyalties(
            _spender,
            metadata,
            newItemId,
            getRoyaltiesRecipientAddress(),
            getPercentageBasisPoints()
        );

        tokenStorage.incrementTotalSupply(_typeId);

        // balance of every token type in user's wallet
        tokenStorage.incrementBalance(_spender, _typeId);

        emit TokenPurchased(
            msg.sender,
            _spender,
            _typeId,
            getTotalSupply(_typeId),
            tokenStorage.getTotalMinted(),
            msg.value
        );
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
     * @param _spender Address receiving the tokens
     * @param _typeId of the token type sold
     */
    function _processPurchase(address _spender, uint256 _typeId, NftTokenBase _token) internal {
        _deliverTokens(_spender, _typeId, _token);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        payable(vault).transfer(msg.value);
    }
}
