// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IManager.sol";
import "./interfaces/ILpProvider.sol";
import "./interfaces/IRoleAccess.sol";
import "./interfaces/ICampaign.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./lib/Constant.sol";

contract Manager is IManager, ILpProvider {

    IRoleAccess private _roles;
    address private _feeVault;
    address private immutable _svLaunchAddress;
    address private immutable _eggAddress;
    
    enum Status {
        Inactive,
        Active,
        Cancelled
    }

     modifier onlyFactory() {
        require(_factoryMap[msg.sender], "Errors.NOT_FACTORY");
        _;
    }
    
    modifier onlyAdmin() {
        require(_roles.isAdmin(msg.sender), "Errors.NOT_ADMIN");
        _;
    }
    
    // Events
    event FactoryRegistered(address indexed deployedAddress);
    event CampaignAdded(address indexed contractAddress, address indexed projectOwner);
    event CampaignCancelled(address indexed contractAddress);
    event FeeVaultChanged(address from, address to);
    event DaoMultiSigEmergencyWithdraw(address contractAddress, address to, address tokenAddress, uint amount);
    
    
    struct CampaignInfo {
        address contractAddress;
        address owner;
        Status status;
    }
    
    struct LpProviderInfo {
        address router;
        address factory;
        bool exist;
    }
    
    // History & list of factories.
    mapping(address => bool) private _factoryMap;
    address[] private _factories;
    
    // History/list of all IDOs
    mapping(uint => CampaignInfo) private _indexCampaignMap; // Starts from 1. Zero is invalid //
    mapping(address => uint) private _addressIndexMap;  // Maps a campaign address to an index in _indexCampaignMap.
    uint private _count;
    
    // Supported Currency
    address[] private _supportedCurrency;
    mapping(address=>bool) private _supportedCurrencyMap;
    
    // Supported LP Providers
    mapping(uint => LpProviderInfo) private _lpProvidersMap;
     
    
    constructor(address svLaunchAddress, address eggAddress, address feeVault, IRoleAccess rolesRegistry) {
        _svLaunchAddress = svLaunchAddress;
        _eggAddress = eggAddress;
        _setFeeVault(feeVault);
        _roles = rolesRegistry;
        
        // Add default BNB
         _supportedCurrency.push(Constant.ZERO_ADDRESS);
         _supportedCurrencyMap[Constant.ZERO_ADDRESS] = true;
    }
    
    
    //--------------------//
    // EXTERNAL FUNCTIONS //
    //--------------------//
    
    function getCampaignInfo(uint id) external view returns (CampaignInfo memory) {
        return _indexCampaignMap[id];
    }
    
    
    function getTotalCampaigns() external view returns (uint) {
        return _count;
    }
    
    function registerFactory(address newFactory) external onlyAdmin {
        if ( _factoryMap[newFactory] == false) {
            _factoryMap[newFactory] = true;
            _factories.push(newFactory);
            emit FactoryRegistered(newFactory);
        }
    }
    
    function isFactory(address contractAddress) external view returns (bool) {
        return _factoryMap[contractAddress];
    }
    
    function getFactory(uint id) external view returns (address) {
        return (  (id < _factories.length) ? _factories[id] : Constant.ZERO_ADDRESS );
    }
    
    function setFeeVault(address newAddress) external onlyAdmin {
        _setFeeVault(newAddress);
    }
    
    function addCurrency(address[] memory tokenAddress) external onlyAdmin {
        
        uint len = tokenAddress.length;
        for (uint n=0; n<len; n++) {
            if (!_currencyExist(tokenAddress[n])) {
                _supportedCurrency.push(tokenAddress[n]);
                _supportedCurrencyMap[tokenAddress[n]] = true;
            }
        }
    }
    
    function enableCurrency(address tokenAddress, bool enable) external onlyAdmin {
        _supportedCurrencyMap[tokenAddress] = enable;
    }

    //------------------------//
    // IMPLEMENTS IManager    //
    //------------------------//
    
    function addCampaign(address newContract, address projectOwner) external override onlyFactory {
        _count++;
        _indexCampaignMap[_count] = CampaignInfo(newContract, projectOwner, Status.Active);
        _addressIndexMap[newContract] = _count;
        emit CampaignAdded(newContract, projectOwner);
    }
    
    function cancelCampaign(address contractAddress) external onlyAdmin {
        uint index = _addressIndexMap[contractAddress];
        CampaignInfo storage info = _indexCampaignMap[index];
        // Update status if campaign is exist & active
        if (info.status == Status.Active) {
            info.status = Status.Cancelled;         
            
            ICampaign(contractAddress).cancelCampaign();
            emit CampaignCancelled(contractAddress);
        }
    }
    
    // Emergency withdrawal to admin address only. Note: Admin is a multiSig dao address.
    function daoMultiSigEmergencyWithdraw(address contractAddress, address tokenAddress, uint amount) external onlyAdmin {
       
        ICampaign(contractAddress).daoMultiSigEmergencyWithdraw(tokenAddress, msg.sender, amount);
        emit DaoMultiSigEmergencyWithdraw(contractAddress, msg.sender, tokenAddress, amount);
    }
    
    function getFeeVault() external override view returns (address) {
        return _feeVault;
    }

    function isCurrencySupported(address currency) external view returns (bool) {
        return _supportedCurrencyMap[currency];
    }
    
    function getSvLaunchAddress() external view override returns (address) {
        return _svLaunchAddress;
    }
    
    function getEggAddress() external view override returns (address) {
        return _eggAddress;
    }
    
    function getRoles() external view override returns (IRoleAccess) {
        return _roles;
    }
    
    function getLpProvider(DataTypes.LpProvider provider) external view override returns (address, address) {
         LpProviderInfo memory item = _lpProvidersMap[uint(provider)];
         return item.exist ? ( item.router, item.factory) : (Constant.ZERO_ADDRESS, Constant.ZERO_ADDRESS);
    }
    
    function checkLpProviders(DataTypes.LpProvider[] calldata providers) external view override returns (bool) {
        uint len = providers.length;
        
        for (uint n=0; n<len; n++) {
            if (!_lpProvidersMap[uint(providers[n])].exist) {
                return false;
            }
        }
        return true;
    }
    
    function getWBnb() external view override returns (address) {
        address router = _lpProvidersMap[uint(DataTypes.LpProvider.PancakeSwap)].router;
        return IUniswapV2Router02(router).WETH();
    }
     
    
    // Set and override any existing provider
    function setLpProvider(uint index, address router, address factory) external onlyAdmin {
        require(router != address(0) && factory != address(0), "Errors.INVALID_ADDRESS");
        _lpProvidersMap[index] = LpProviderInfo(router, factory, true);
    }
    
    //--------------------//
    // PRIVATE FUNCTIONS //
    //--------------------//
    
    function _setFeeVault(address newAddress) private {
        require(newAddress!=address(0), "Errors.INVALID_ADDRESS");
        emit FeeVaultChanged(_feeVault, newAddress);
        _feeVault = newAddress;
    }
    
    function _currencyExist(address currency) private view returns (bool) {
        uint len = _supportedCurrency.length;
        for (uint n=0;n<len;n++) {
            if (_supportedCurrency[n]==currency) {
                return true;
            }   
        }
        return false;
    }
}

