// SPDX-License-Identifier: MIT
// @lamenix

pragma solidity 0.8.17;

import "./ERC20.sol";
import "./IPancake.sol";
import "./GasHelper.sol";
import "./SwapHelper.sol";

contract AiShiba is GasHelper, ERC20 {
  address constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address constant ZERO = 0x0000000000000000000000000000000000000000;

  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // ? PROD
  // address constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // ? TESTNET
  address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // ? PROD
  // address constant PANCAKE_ROUTER = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; // ? TESTNET

  string constant NAME = "Ai Shiba";
  string constant SYMBOL = "AISHIBA";

  string public constant URL = "www.aishiba.com";

  uint constant MAX_SUPPLY = 100_000_000_000_000e18;

  // Wallets limits
  uint public minAmountToAutoSwap = 10000 * (10 ** decimals()); // 100

  // Fees
  uint constant public FEE_POOL = 100;
  uint constant public FEE_REFLECT = 100;
  uint constant public FEE_ADMINISTRATION_WALLET = 300;

  uint constant MAX_TOTAL_FEE = 1000;

  mapping(address => uint) public specialFeesByWalletSender;
  mapping(address => uint) public specialFeesByWalletReceiver;

  // Helpers
  bool private _noReentrance;

  bool public pausedSwapPool; // if disabled stores the pool fees as token instead WBNB
  bool public pausedSwapAdmin; // if disabled stores the admin fees as token instead WBNB

  bool public disabledReflect;
  bool public disabledAutoLiquidity;

  // Counters
  uint public totalBurned;
  uint public accumulatedToReflect;
  uint public accumulatedToAdmin;
  uint public accumulatedToPool;

  // Liquidity Pair
  address public liquidityPool;

  // Wallets
  address public administrationWallet;
  address public swapHelperAddress;

  // Reflect VARIABLES
  mapping(address => HolderShare) public holderMap;

  uint private constant REFLECT_PRECISION = 10 ** 18;
  uint private reflectPerShare;

  uint public minTokenHoldToReflect = 100 * (10 ** decimals()); // min holder must have to be able to receive reflect
  uint public totalTokens;

  struct HolderShare {
    uint amountToken;
    uint totalReceived;
    uint entryPointMarkup;
  }

  receive() external payable {}

  constructor() ERC20(NAME, SYMBOL) {
    permissions[0][_msgSender()] = true;
    permissions[1][_msgSender()] = true;
    permissions[2][_msgSender()] = true;

    PancakeRouter router = PancakeRouter(PANCAKE_ROUTER);
    liquidityPool = address(PancakeFactory(router.factory()).createPair(WBNB, address(this)));

    uint baseAttributes = 0;
    baseAttributes = setExemptReflect(baseAttributes, true);

    _attributeMap[liquidityPool] = baseAttributes;
    _attributeMap[DEAD] = baseAttributes;
    _attributeMap[ZERO] = baseAttributes;

    baseAttributes = setExemptFeeSender(baseAttributes, true);
    _attributeMap[address(this)] = baseAttributes;

    baseAttributes = setExemptSwapperMaker(baseAttributes, true);
    baseAttributes = setExemptFeeReceiver(baseAttributes, true);

    _attributeMap[_msgSender()] = baseAttributes;

    SwapHelper swapHelper = new SwapHelper();
    swapHelper.safeApprove(WBNB, address(this), type(uint).max);
    swapHelper.transferOwnership(_msgSender());
    swapHelperAddress = address(swapHelper);

    _attributeMap[swapHelperAddress] = baseAttributes;

    _mint(_msgSender(), MAX_SUPPLY);
  }

  // ----------------- Public Views -----------------
  function getOwner() external view returns (address) {
    return owner();
  }

  function getFeeTotal() public pure returns (uint) {
    return FEE_POOL + FEE_REFLECT + FEE_ADMINISTRATION_WALLET;
  }

  function getSpecialWalletFee(address target, bool isSender) public view returns (uint reflect, uint pool, uint adminFee) {
    uint composedValue = isSender ? specialFeesByWalletSender[target] : specialFeesByWalletReceiver[target];
    reflect = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    pool = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    adminFee = composedValue % 1e4;
  }

  function balanceOf(address account) public view override returns (uint) {
    uint entryPointMarkup = holderMap[account].entryPointMarkup;
    uint totalToBePaid = (holderMap[account].amountToken * reflectPerShare) / REFLECT_PRECISION;
    return _balances[account] + (totalToBePaid <= entryPointMarkup ? 0 : totalToBePaid - entryPointMarkup);
  }

  // ----------------- Authorized Methods -----------------
  function setLiquidityPool(address newPair) external isAuthorized(0) {
    require(newPair != ZERO, "Invalid address");
    liquidityPool = newPair;
  }

  function setPausedSwapPool(bool state) external isAuthorized(0) {
    pausedSwapPool = state;
  }

  function setPausedSwapAdmin(bool state) external isAuthorized(0) {
    pausedSwapAdmin = state;
  }

  function setDisabledReflect(bool state) external isAuthorized(0) {
    disabledReflect = state;
  }

  function setDisabledAutoLiquidity(bool state) external isAuthorized(0) {
    disabledAutoLiquidity = state;
  }

  // ----------------- Wallets Settings -----------------
  function setAdministrationWallet(address account) public isAuthorized(0) {
    administrationWallet = account;
  }

  // ----------------- Fee Settings -----------------

  function setSpecialWalletFeeOnSend(address target, uint reflect, uint pool, uint adminFee) public isAuthorized(1) {
    setSpecialWalletFee(target, true, reflect, pool, adminFee);
  }

  function setSpecialWalletFeeOnReceive(address target, uint reflect, uint pool, uint adminFee) public isAuthorized(1) {
    setSpecialWalletFee(target, false, reflect, pool, adminFee);
  }

  function setSpecialWalletFee(address target, bool isSender, uint reflect, uint pool, uint adminFee) private {
    uint total = reflect + pool + adminFee;
    require(total <= MAX_TOTAL_FEE, "All rates and fee together must be lower than 10%");
    uint composedValue = reflect + (pool * 1e4) + (adminFee * 1e8);
    if (isSender) {
      specialFeesByWalletSender[target] = composedValue;
    } else {
      specialFeesByWalletReceiver[target] = composedValue;
    }
  }

  // ----------------- Token Flow Settings -----------------

  function setMinAmountToAutoSwap(uint amount) public isAuthorized(1) {
    minAmountToAutoSwap = amount;
  }

  struct Receivers {
    address wallet;
    uint amount;
  }

  function multiTransfer(address[] calldata wallets, uint[] calldata amount) external {
    uint length = wallets.length;
    require(amount.length == length, "Invalid size os lists");
    for (uint i = 0; i < length; i++) transfer(wallets[i], amount[i]);
  }

  // ----------------- External Methods -----------------
  function burn(uint amount) external {
    _burn(_msgSender(), amount);
  }

  // ----------------- Internal CORE -----------------
  function _transfer(address sender, address receiver, uint amount) internal override {
    require(amount > 0, "Invalid Amount");
    require(!_noReentrance, "ReentranceGuard Alert");
    _noReentrance = true;

    uint senderAttributes = _attributeMap[sender];
    uint receiverAttributes = _attributeMap[receiver];

    // Initial Checks
    require(sender != ZERO && receiver != ZERO, "transfer from / to the zero address");

    // Update Sender Balance to add pending staking
    if (!isExemptReflect(senderAttributes) && !disabledReflect) _updateHolder(sender, _balances[sender], minTokenHoldToReflect, reflectPerShare);
    uint senderBalance = _balances[sender];
    require(senderBalance >= amount, "Transfer amount exceeds your balance");
    senderBalance -= amount;
    _balances[sender] = senderBalance;

    uint adminFee;
    uint poolFee;
    uint reflectFee;

    // Calculate Fees
    uint feeAmount = 0;
    if (!isExemptFeeSender(senderAttributes) && !isExemptFeeReceiver(receiverAttributes)) {
      if (isSpecialFeeWalletSender(senderAttributes)) {
        (reflectFee, poolFee, adminFee) = getSpecialWalletFee(sender, true); // Check special wallet fee on sender
      } else if (isSpecialFeeWalletReceiver(receiverAttributes)) {
        (reflectFee, poolFee, adminFee) = getSpecialWalletFee(receiver, false); // Check special wallet fee on receiver
      } else {
        adminFee = FEE_ADMINISTRATION_WALLET;
        poolFee = FEE_POOL;
        reflectFee = FEE_REFLECT;
      }
      feeAmount = ((reflectFee + poolFee + adminFee) * amount) / 10_000;
    }

    if (feeAmount != 0) splitFee(feeAmount, sender, adminFee, poolFee, reflectFee);
    if ((!pausedSwapPool || !pausedSwapAdmin) && !isExemptSwapperMaker(senderAttributes)) autoSwap(sender);

    // Update Recipient Balance
    uint newRecipientBalance = _balances[receiver] + (amount - feeAmount);
    _balances[receiver] = newRecipientBalance;

    if (!disabledReflect) executeReflectOperations(sender, receiver, senderBalance, newRecipientBalance, senderAttributes, receiverAttributes);

    _noReentrance = false;
    emit Transfer(sender, receiver, amount - feeAmount);
  }

  function operateSwap(address liquidityPair, address swapHelper, uint amountIn) private returns (uint) {
    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
    bool reversed = isReversed(liquidityPair, WBNB);

    if (reversed) {
      uint112 temp = reserve0;
      reserve0 = reserve1;
      reserve1 = temp;
    }

    _balances[liquidityPair] += amountIn;
    uint wbnbAmount = getAmountOut(amountIn, reserve1, reserve0);
    if (!reversed) {
      swapToken(liquidityPair, wbnbAmount, 0, swapHelper);
    } else {
      swapToken(liquidityPair, 0, wbnbAmount, swapHelper);
    }
    return wbnbAmount;
  }

  function autoSwap(address sender) private {
    // --------------------- Execute Auto Swap -------------------------
    address liquidityPair = liquidityPool;
    address swapHelper = swapHelperAddress;

    if (sender == liquidityPair) return;

    uint poolAmount = disabledAutoLiquidity ? accumulatedToPool : accumulatedToPool / 2;
    uint adminAmount = accumulatedToAdmin;
    uint totalAmount = poolAmount + adminAmount;

    if (totalAmount < minAmountToAutoSwap) return;

    // Execute auto swap
    uint amountOut = operateSwap(liquidityPair, swapHelper, totalAmount);

    // --------------------- Add Liquidity -------------------------
    if (poolAmount > 0) {
      if (!disabledAutoLiquidity) {
        uint amountToSend = (amountOut * poolAmount) / (totalAmount);
        (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
        bool reversed = isReversed(liquidityPair, WBNB);
        if (reversed) {
          uint112 temp = reserve0;
          reserve0 = reserve1;
          reserve1 = temp;
        }

        uint amountA;
        uint amountB;
        {
          uint amountBOptimal = (amountToSend * reserve1) / reserve0;
          if (amountBOptimal <= poolAmount) {
            (amountA, amountB) = (amountToSend, amountBOptimal);
          } else {
            uint amountAOptimal = (poolAmount * reserve0) / reserve1;
            assert(amountAOptimal <= amountToSend);
            (amountA, amountB) = (amountAOptimal, poolAmount);
          }
        }
        tokenTransferFrom(WBNB, swapHelper, liquidityPair, amountA);
        _balances[liquidityPair] += amountB;
        IPancakePair(liquidityPair).mint(address(this));
      } else {
        uint amountToSend = (amountOut * poolAmount) / (totalAmount);
        tokenTransferFrom(WBNB, swapHelper, address(this), amountToSend);
      }
    }

    // --------------------- Transfer Swapped Amount -------------------------
    if (adminAmount > 0) {
      uint amountToSend = (amountOut * adminAmount) / (totalAmount);
      tokenTransferFrom(WBNB, swapHelper, administrationWallet, amountToSend);
    }

    accumulatedToPool = 0;
    accumulatedToAdmin = 0;
  }

  function splitFee(uint incomingFeeAmount, address sender, uint adminFee, uint poolFee, uint reflectFee) private {
    uint totalFee = adminFee + poolFee + reflectFee;

    if (reflectFee > 0) {
      accumulatedToReflect += (incomingFeeAmount * reflectFee) / totalFee;
    }

    // Administrative distribution
    if (adminFee > 0) {
      accumulatedToAdmin += (incomingFeeAmount * adminFee) / totalFee;
      if (pausedSwapAdmin) {
        address wallet = administrationWallet;
        uint walletBalance = _balances[wallet] + accumulatedToAdmin;
        _balances[wallet] = walletBalance;
        if (!isExemptReflect(_attributeMap[wallet]) && !disabledReflect) _updateHolder(wallet, walletBalance, minTokenHoldToReflect, reflectPerShare);
        emit Transfer(sender, wallet, accumulatedToAdmin);
        accumulatedToAdmin = 0;
      }
    }

    // Pool Distribution
    if (poolFee > 0) {
      accumulatedToPool += (incomingFeeAmount * poolFee) / totalFee;
      if (pausedSwapPool) {
        _balances[address(this)] += accumulatedToPool;
        emit Transfer(sender, address(this), accumulatedToPool);
        accumulatedToPool = 0;
      }
    }
  }

  // --------------------- Reflect Internal Methods -------------------------

  function setMinTokenHoldToReflect(uint amount) external isAuthorized(1) {
    minTokenHoldToReflect = amount;
  }

  function executeReflectOperations(address sender, address receiver, uint senderAmount, uint receiverAmount, uint senderAttributes, uint receiverAttributes) private {
    uint minTokenHolder = minTokenHoldToReflect;
    uint reflectPerShareValue = reflectPerShare;

    if (!isExemptReflect(senderAttributes)) _updateHolder(sender, senderAmount, minTokenHolder, reflectPerShareValue);

    // Calculate new reflect per share value
    uint accumulated = accumulatedToReflect;
    if (accumulated > 0) {
      uint consideredTotalTokens = totalTokens;
      reflectPerShareValue += (accumulated * REFLECT_PRECISION) / (consideredTotalTokens == 0 ? 1 : consideredTotalTokens);
      reflectPerShare = reflectPerShareValue;
      accumulatedToReflect = 0;
    }

    if (!isExemptReflect(receiverAttributes)) _updateHolder(receiver, receiverAmount, minTokenHolder, reflectPerShareValue);
  }

  function _updateHolder(address holder, uint amount, uint minTokenHolder, uint reflectPerShareValue) private {
    // If holder has less than minTokenHoldToReflect, then does not participate on staking
    uint consideredAmount = minTokenHolder <= amount ? amount : 0;
    uint holderAmount = holderMap[holder].amountToken;

    if (holderAmount > 0) {
      uint entryPointMarkup = holderMap[holder].entryPointMarkup;
      uint totalToBePaid = (holderAmount * reflectPerShareValue) / REFLECT_PRECISION;
      if (totalToBePaid > entryPointMarkup) {
        uint toReceive = totalToBePaid - entryPointMarkup;
        _balances[holder] += toReceive;
        holderMap[holder].totalReceived += toReceive;
      }
    }

    totalTokens = (totalTokens - holderAmount) + consideredAmount;
    holderMap[holder].amountToken = consideredAmount;
    holderMap[holder].entryPointMarkup = (consideredAmount * reflectPerShareValue) / REFLECT_PRECISION;
  }
}
