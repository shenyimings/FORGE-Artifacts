// SPDX-License-Identifier: AGPL-3.0-or-later
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStablecoinAdapter.sol";
import "../interfaces/IStablecoin.sol";
import "../interfaces/IBookKeeper.sol";
import "../interfaces/IAuthTokenAdapter.sol";
import "../interfaces/IStableSwapModule.sol";

// Stable Swap Module
// Allows anyone to go between AUSD and the Token by pooling the liquidity
// An optional fee is charged for incoming and outgoing transfers

contract StableSwapModule is PausableUpgradeable, ReentrancyGuardUpgradeable, IStableSwapModule {
  IBookKeeper public bookKeeper;
  IAuthTokenAdapter public override authTokenAdapter;
  IStablecoin public stablecoin;
  IStablecoinAdapter public override stablecoinAdapter;
  bytes32 public collateralPoolId;
  address public systemDebtEngine;

  uint256 internal to18ConversionFactor;

  uint256 public feeIn; // fee in [wad]
  uint256 public feeOut; // fee out [wad]

  // --- Events ---
  event LogSetFeeIn(address indexed _caller, uint256 _feeIn);
  event LogSetFeeOut(address indexed _caller, uint256 _feeOut);
  event LogSwapTokenToStablecoin(address indexed _owner, uint256 _value, uint256 _fee);
  event LogSwapStablecoinToToken(address indexed _owner, uint256 _value, uint256 _fee);

  // --- Init ---
  function initialize(
    address _authTokenAdapter,
    address _stablecoinAdapter,
    address _systemDebtEngine
  ) external initializer {
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    IAuthTokenAdapter __authTokenAdapter = authTokenAdapter = IAuthTokenAdapter(_authTokenAdapter);
    IStablecoinAdapter __stablecoinAdapter = stablecoinAdapter = IStablecoinAdapter(_stablecoinAdapter);
    IBookKeeper _bookKeeper = bookKeeper = IBookKeeper(address(__authTokenAdapter.bookKeeper()));
    IStablecoin _stablecoin = stablecoin = IStablecoin(address(__stablecoinAdapter.stablecoin()));
    collateralPoolId = __authTokenAdapter.collateralPoolId();
    systemDebtEngine = _systemDebtEngine;
    to18ConversionFactor = 10**(18 - __authTokenAdapter.decimals());
    _stablecoin.approve(_stablecoinAdapter, uint256(-1));
    _bookKeeper.whitelist(_stablecoinAdapter);
  }

  // --- Math ---
  uint256 constant WAD = 10**18;
  uint256 constant RAY = 10**27;

  function add(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require((_z = _x + _y) >= _x);
  }

  function sub(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require((_z = _x - _y) <= _x);
  }

  function mul(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require(_y == 0 || (_z = _x * _y) / _y == _x);
  }

  function setFeeIn(uint256 _feeIn) external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    require(_feeIn <= 5 * 1e17, "StableSwapModule/invalid-fee-in"); // Max feeIn is 0.5 Ethers or 50%
    feeIn = _feeIn;
    emit LogSetFeeIn(msg.sender, _feeIn);
  }

  function setFeeOut(uint256 _feeOut) external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    require(_feeOut <= 5 * 1e17, "StableSwapModule/invalid-fee-in"); // Max feeOut is 0.5 Ethers or 50%
    feeOut = _feeOut;
    emit LogSetFeeOut(msg.sender, _feeOut);
  }

  // hope can be used to transfer control of the PSM vault to another contract
  // This can be used to upgrade the contract
  function whitelist(address _usr) external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    bookKeeper.whitelist(_usr);
  }

  function blacklist(address _usr) external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    bookKeeper.blacklist(_usr);
  }

  // --- Primary Functions ---
  /**
   * @dev Deposit token into the system and withdraw to receive stablecoin
   * @param _usr The address of the account to sell
   * @param _tokenAmount The Amount of token to sell
   */
  function swapTokenToStablecoin(address _usr, uint256 _tokenAmount) external override nonReentrant whenNotPaused {
    uint256 _tokenAmount18 = mul(_tokenAmount, to18ConversionFactor);
    uint256 _fee = mul(_tokenAmount18, feeIn) / WAD;
    uint256 _stablecoinAmount = sub(_tokenAmount18, _fee);
    authTokenAdapter.deposit(address(this), _tokenAmount, msg.sender);
    bookKeeper.adjustPosition(
      collateralPoolId,
      address(this),
      address(this),
      address(this),
      int256(_tokenAmount18),
      int256(_tokenAmount18)
    );
    bookKeeper.moveStablecoin(address(this), systemDebtEngine, mul(_fee, RAY));
    stablecoinAdapter.withdraw(_usr, _stablecoinAmount, abi.encode(0));

    emit LogSwapTokenToStablecoin(_usr, _tokenAmount, _fee);
  }

  /**
   * @dev Deposit stablecoin into the system and withdraw to receive token
   * @param _usr The address of the account to buy
   * @param _tokenAmount The Amount of token to buy
   */
  function swapStablecoinToToken(address _usr, uint256 _tokenAmount) external override nonReentrant whenNotPaused {
    uint256 _tokenAmount18 = mul(_tokenAmount, to18ConversionFactor);
    uint256 _fee = mul(_tokenAmount18, feeOut) / WAD;
    uint256 _stablecoinAmount = add(_tokenAmount18, _fee);
    require(stablecoin.transferFrom(msg.sender, address(this), _stablecoinAmount), "StableSwapModule/failed-transfer");
    stablecoinAdapter.deposit(address(this), _stablecoinAmount, abi.encode(0));
    bookKeeper.adjustPosition(
      collateralPoolId,
      address(this),
      address(this),
      address(this),
      -int256(_tokenAmount18),
      -int256(_tokenAmount18)
    );
    authTokenAdapter.withdraw(_usr, _tokenAmount);
    bookKeeper.moveStablecoin(address(this), systemDebtEngine, mul(_fee, RAY));

    emit LogSwapStablecoinToToken(_usr, _tokenAmount, _fee);
  }

  // --- pause ---
  function pause() external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(_accessControlConfig.GOV_ROLE(), msg.sender),
      "!(ownerRole or govRole)"
    );
    _pause();
  }

  function unpause() external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(_accessControlConfig.GOV_ROLE(), msg.sender),
      "!(ownerRole or govRole)"
    );
    _unpause();
  }
}
