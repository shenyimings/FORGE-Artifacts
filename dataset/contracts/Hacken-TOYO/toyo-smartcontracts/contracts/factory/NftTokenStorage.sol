// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NftTokenStorage is AccessControl, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    struct tokenType {
        string metadata;
        uint256 rate;
        uint256 maxSupply;
        Counters.Counter totalSupply;
        uint256 purchaseCap;
        bool pause;
    }

    struct wallet {
        uint256 lastPurchase;
        uint256 contribution;
        mapping(uint256 => Counters.Counter) balance;
    }

    mapping(uint256 => tokenType) private _types;
    mapping(address => wallet) private _wallets;

    mapping(address => bool) private _blacklist;
    mapping(address => bool) private _whitelist;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIds;
    Counters.Counter private _tokenTypeIds;

    // Amount of wei raised
    uint256 public weiRaised;

    // Time lock in seconds for new purchases from the same wallet
    uint256 public coolDowmSeconds;

    bool public isWhitelistEnabled;
    bool public isBlacklistEnabled;

    address payable public royaltiesRecipientAddress;
    uint96 public percentageBasisPoints;

    function getMetadata(uint256 _typeId) public view returns (string memory) {
        return _types[_typeId].metadata;
    }

    function getRate(uint256 _typeId) public view returns (uint256) {
        return _types[_typeId].rate;
    }

    function getMaxSupply(uint256 _typeId) public view returns (uint256) {
        return _types[_typeId].maxSupply;
    }

    function getTotalSupply(uint256 _typeId) public view returns (uint256) {
        return _types[_typeId].totalSupply.current();
    }

    function getPurchaseCap(uint256 _typeId) public view returns (uint256) {
        return _types[_typeId].purchaseCap;
    }

    function isPaused(uint256 _typeId) public view returns (bool) {
        return _types[_typeId].pause;
    }

    function getUserContribution(address _account)
        public
        view
        returns (uint256)
    {
        return _wallets[_account].contribution;
    }

    function balanceOf(address _owner, uint256 _typeId)
        public
        view
        returns (uint256)
    {
        return _wallets[_owner].balance[_typeId].current();
    }

    function getTotalMinted() public view returns (uint256) {
        return _tokenIds.current();
    }

    function getLastTypeId() public view returns (uint256) {
        return _tokenTypeIds.current();
    }

    function getLastPurchaseTime(address _spender)
        public
        view
        returns (uint256)
    {
        return _wallets[_spender].lastPurchase;
    }

    function setLastPurchaseTime(address _spender, uint256 _timestamp)
        public
        onlyRole(MINTER_ROLE)
    {
        _wallets[_spender].lastPurchase = _timestamp;
    }

    function setUserContribution(address _spender, uint256 _contribution)
        public
        onlyRole(MINTER_ROLE)
    {
        _wallets[_spender].contribution = _contribution;
    }

    function setMetadata(uint256 _typeId, string memory _metadata)
        public
        onlyRole(MINTER_ROLE)
    {
        _types[_typeId].metadata = _metadata;
    }

    function setRate(uint256 _typeId, uint256 _rate)
        public
        onlyRole(MINTER_ROLE)
    {
        _types[_typeId].rate = _rate;
    }

    function setWhitelist(bool _enable) public onlyRole(MINTER_ROLE) {
        isWhitelistEnabled = _enable;
    }

    function addToWhitelist(address _account)
        public
        onlyRole(MINTER_ROLE)
    {
        _whitelist[_account] = true;
    }

    function removeFromWhitelist(address _account)
        public
        onlyRole(MINTER_ROLE)
    {
        _whitelist[_account] = false;
    }

    function isWhitelisted(address _account)
        public
        onlyRole(MINTER_ROLE)
        view
        returns (bool)
    {
       return _whitelist[_account];
    }

    function setBlacklist(bool _enable) public onlyRole(MINTER_ROLE) {
        isBlacklistEnabled = _enable;
    }

    function addToBlacklist(address _account)
        public
        onlyRole(MINTER_ROLE)
    {
        _blacklist[_account] = true;
    }

    function removeFromBlacklist(address _account)
        public
        onlyRole(MINTER_ROLE)
    {
        _blacklist[_account] = false;
    }

    function isBlacklisted(address _account)
        public
        view
        returns (bool)
    {
       return _blacklist[_account];
    }

    function setMaxSupply(uint256 _typeId, uint256 _maxSupply)
        public
        onlyRole(MINTER_ROLE)
    {
        _types[_typeId].maxSupply = _maxSupply;
    }

    function setCoolDown(uint256 _seconds) public onlyRole(MINTER_ROLE) {
        coolDowmSeconds = _seconds;
    }

    function setPurchaseCap(uint256 _typeId, uint256 _cap)
        public
        onlyRole(MINTER_ROLE)
    {
        _types[_typeId].purchaseCap = _cap;
    }

    function setRoyaltiesRecipientAddress(address payable _to)
        public
        onlyRole(MINTER_ROLE)
    {
        royaltiesRecipientAddress = _to;
    }

    function setPercentageBasisPoints(uint96 _percentage)
        public
        onlyRole(MINTER_ROLE)
    {
        percentageBasisPoints = _percentage;
    }

    function setWeiRaised(uint256 _wei) public onlyRole(MINTER_ROLE) {
        weiRaised = _wei;
    }

    function setPause(uint256 _typeId, bool _pause) public onlyRole(MINTER_ROLE) {
        _types[_typeId].pause = _pause;
    }

    function incrementTotalSupply(uint256 _typeId)
        public
        onlyRole(MINTER_ROLE)
    {
        _types[_typeId].totalSupply.increment();
    }

    function incrementBalance(address _owner, uint256 _typeId)
        public
        onlyRole(MINTER_ROLE)
    {
        _wallets[_owner].balance[_typeId].increment();
    }

    function incrementTokenId() public onlyRole(MINTER_ROLE) {
        _tokenIds.increment();
    }

    function incrementTypeId() public onlyRole(MINTER_ROLE) {
        _tokenTypeIds.increment();
    }
}
