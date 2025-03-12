// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../DID/interfaces/IPSBT.sol";
import "../VaultMSData.sol";

interface IVault {
    function priceFeed() external view returns (address);
    function vaultStorage() external view returns (address);
    function usdx() external view returns (address);
    function totalTokenWeights() external view returns (uint256);
    function usdxAmounts(address _token) external view returns (uint256);
    function guaranteedUsd(address _token) external view returns (uint256);
    function baseMode() external view returns (uint8);

    function approvedRouters(address _router) external view returns (bool);
    function isManager(address _account) external view returns (bool);

    // function feeReserves(address _token) external view returns (uint256);
    // function feeSold (address _token)  external view returns (uint256);
    // function feeReservesUSD() external view returns (uint256);
    // function feeReservesDiscountedUSD() external view returns (uint256);
    // function feeClaimedUSD() external view returns (uint256);
    function globalShortSize( ) external view returns (uint256);
    function globalLongSize( ) external view returns (uint256);


    //---------------------------------------- owner FUNCTIONS --------------------------------------------------
    // function setPSBT(address _psbt) external;
    // function setVaultStorage(address _vaultStorage) external;
    // function setVaultUtils(address _vaultUtils) external;
    // function setPriceFeed(address _priceFeed) external;

    function setManager(address _manager, bool _isManager) external;
    function setRouter(address _router, bool _status) external;
    function setTokenConfig(address _token, uint256 _tokenWeight, bool _isStable, bool _isFundingToken, bool _isTradingToken) external;
    function clearTokenConfig(address _token, bool _del) external;
    function updateRate(address _token) external;

    //-------------------------------------------------- FUNCTIONS FOR MANAGER --------------------------------------------------
    function buyUSD(address _token) external returns (uint256);
    function sellUSD(address _token, address _receiver, uint256 _usdxAmount) external returns (uint256);


    //---------------------------------------- TRADING FUNCTIONS --------------------------------------------------
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external;


    //-------------------------------------------------- PUBLIC FUNCTIONS --------------------------------------------------
    function directPoolDeposit(address _token) external;
    function tradingTokenList() external view returns (address[] memory);
    function fundingTokenList() external view returns (address[] memory);


    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);
    // function getRedemptionAmount(address _token, uint256 _usdxAmount) external view returns (uint256);
    function tokenToUsdMin(address _token, uint256 _tokenAmount) external view returns (uint256);
    function usdToTokenMax(address _token, uint256 _usdAmount) external view returns (uint256);
    function usdToTokenMin(address _token, uint256 _usdAmount) external view returns (uint256);


    function isFundingToken(address _token) external view returns(bool);
    function isTradingToken(address _token) external view returns(bool);
    // function tokenDecimals(address _token) external view returns (uint256);
    function getPositionStructByKey(bytes32 _key) external view returns (VaultMSData.Position memory);
    function getPositionStruct(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (VaultMSData.Position memory);
    function getTokenBase(address _token) external view returns (VaultMSData.TokenBase memory);
    function getTradingFee(address _token) external view returns (VaultMSData.TradingFee memory);
    function getTradingRec(address _token) external view returns (VaultMSData.TradingRec memory);
    function getUserKeys(address _account, uint256 _start, uint256 _end) external view returns (bytes32[] memory);
    function getKeys(uint256 _start, uint256 _end) external view returns (bytes32[] memory);
}
