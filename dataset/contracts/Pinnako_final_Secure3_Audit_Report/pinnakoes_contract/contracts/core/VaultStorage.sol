// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/EnumerableValues.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultStorage.sol";

contract VaultStorage is Ownable, IVaultStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableValues for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;

    EnumerableSet.Bytes32Set private positionKeys; // Record positions keys tracks all open positions
    mapping(address => EnumerableSet.Bytes32Set) private userKeys;
    
    bool public override isSwapEnabled = true;
    


    //trading limit part
    mapping(address => uint256) public override maxGlobalShortSizes;
    mapping(address => uint256) public override maxGlobalLongSizes;
    mapping(address => VaultMSData.TradingLimit) tradingLimit;
  


    IVault public vault;
    
    modifier onlyVault() {
        require(msg.sender == address(vault) || msg.sender == owner(), "onlyVault");
        _;
    }

    constructor(IVault _vault) {
        vault = _vault;
    }

    function withdrawToken( address _account, address _token, uint256 _amount ) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }

    // ---------- owner setting part ----------
    function setVault(address _vault) external override onlyOwner{
        vault = IVault(_vault);
    }

    function setIsSwapEnabled(bool _isSwapEnabled) external onlyOwner{
        isSwapEnabled = _isSwapEnabled;
    }

    function setMaxGlobalSize(address _token, uint256 _amountLong, uint256 _amountShort) external onlyOwner{
        maxGlobalLongSizes[_token] = _amountLong;
        maxGlobalShortSizes[_token] = _amountShort;
    }

    function setTradingLimit(address _token, uint256 _maxShortSize, uint256 _maxLongSize, uint256 _maxSize, uint256 _maxRatio, uint256 _countMinSize) external onlyOwner{
        VaultMSData.TradingLimit storage tLim = tradingLimit[_token];
        tLim.maxTradingSize = _maxSize;
        tLim.maxShortSize = _maxShortSize;
        tLim.maxLongSize = _maxLongSize;
        tLim.countMinSize = _countMinSize;
        tLim.maxRatio = _maxRatio;
    }

    function getTradingLimit(address _token) public override view returns (VaultMSData.TradingLimit memory){
        return tradingLimit[_token];
    }


    function delKey(address _account, bytes32 _key) external override onlyVault{
        if (positionKeys.contains(_key))
            positionKeys.remove(_key);
        if (userKeys[_account].contains(_key))
            userKeys[_account].remove(_key);        
    }

    function addKey(address _account, bytes32 _key) external override onlyVault{
        if (!positionKeys.contains(_key))
            positionKeys.add(_key);
        if (!userKeys[_account].contains(_key))
            userKeys[_account].add(_key);        
    }


    function userKeysLength(address _account) external override view returns (uint256){
        return userKeys[_account].length();
    }

    function totalKeysLength( ) external override view returns (uint256){
        return positionKeys.length();
    }

    function getUserKeys(address _account, uint256 _start, uint256 _end) external override view returns (bytes32[] memory){
        uint256 _kLength = userKeys[_account].length();
        return userKeys[_account].valuesAt(_start, _end > _kLength ? _kLength : _end);
    }
    function getKeys(uint256 _start, uint256 _end) external override view returns (bytes32[] memory){
        uint256 _kLength = positionKeys.length();
        return positionKeys.valuesAt(_start, _end > _kLength ? _kLength : _end);
    }

}
