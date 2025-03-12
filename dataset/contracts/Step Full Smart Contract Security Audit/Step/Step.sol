// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./BEP20.sol";
import "./IDEX.sol";

contract Step is BEP20 {
  IDexRouter public constant ROUTER = IDexRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
  address public immutable pair;

  address public marketingWallet;
  address public rewardWallet;

  uint256 public swapThreshold = 150000 * 10**18;
  bool public swapEnabled = true;

  bool dumpProtectionEnabled = true;
  bool sniperTax = true;
  bool tradingEnabled;
  bool inSwap;

  uint256 public buyTax = 1000;
  uint256 public sellTax = 1000;
  uint256 public transferTax = 0;
  uint256 public rewardShare = 250;
  uint256 public liquidityShare = 200;
  uint256 public marketingShare = 550;
  uint256 totalShares = 1000;
  uint256 constant TAX_DENOMINATOR = 10000;

  uint256 public transferGas = 25000;
  uint256 public launchTime;

  mapping (address => bool) public isWhitelisted;
  mapping (address => bool) public isCEX;
  mapping (address => bool) public isMarketMaker;

  event DisableDumpProtection();
  event EnableTrading();
  event TriggerSwapBack();
  event RecoverBNB(uint256 amount);
  event RecoverBEP20(address indexed token, uint256 amount);
  event SetWhitelisted(address indexed account, bool indexed status);
  event SetCEX(address indexed account, bool indexed exempt);
  event SetMarketMaker(address indexed account, bool indexed isMM);
  event SetTaxes(uint256 reward, uint256 liquidity, uint256 marketing);
  event SetShares(uint256 rewardShare, uint256 liquidityShare, uint256 marketingShare);
  event SetSwapBackSettings(bool enabled, uint256 amount);
  event SetTransferGas(uint256 newGas, uint256 oldGas);
  event SetMarketingWallet(address newWallet, address oldWallet);
  event SetRewardWallet(address newAddress, address oldAddress);
  event AutoLiquidity(uint256 pair, uint256 tokens);
  event DepositMarketing(address indexed wallet, uint256 amount);
  event DepositRewards(address indexed wallet, uint256 amount);

  modifier swapping() { 
    inSwap = true;
    _;
    inSwap = false;
  }

  constructor(address owner, address marketing, address rewards) BEP20(owner, marketing) {
    pair = IDexFactory(ROUTER.factory()).createPair(ROUTER.WETH(), address(this));
    _approve(address(this), address(ROUTER), type(uint256).max);
    isMarketMaker[pair] = true;

    rewardWallet = rewards;
    marketingWallet = marketing;
    isWhitelisted[marketingWallet] = true;
  }

  // Override

  function _transfer(address sender, address recipient, uint256 amount) internal override {
    if (isWhitelisted[sender] || isWhitelisted[recipient] || inSwap) {
      super._transfer(sender, recipient, amount);
      return;
    }
    require(tradingEnabled, "Trading is disabled");

    if (_shouldSwapBack(recipient)) { _swapBack(); }
    uint256 amountAfterTaxes = _takeTax(sender, recipient, amount);

    super._transfer(sender, recipient, amountAfterTaxes);
  }

  // Public

  function getDynamicSellTax() public view returns (uint256) {
    uint256 endingTime = launchTime + 1 days;

    if (endingTime > block.timestamp) {
      uint256 remainingTime = endingTime - block.timestamp;
      return sellTax + sellTax * remainingTime / 1 days;
    } else {
      return sellTax;
    }
  }

  receive() external payable {}

  // Private

  function _takeTax(address sender, address recipient, uint256 amount) private returns (uint256) {
    if (amount == 0) { return amount; }

    uint256 taxAmount = amount * _getTotalTax(sender, recipient) / TAX_DENOMINATOR;
    if (taxAmount > 0) { super._transfer(sender, address(this), taxAmount); }

    return amount - taxAmount;
  }

  function _getTotalTax(address sender, address recipient) private view returns (uint256) {
    if (sniperTax) { return TAX_DENOMINATOR - 100; }
    if (isCEX[recipient]) { return 0; }
    if (isCEX[sender]) { return buyTax; }

    if (isMarketMaker[sender]) {
      return buyTax;
    } else if (isMarketMaker[recipient]) {
      return dumpProtectionEnabled ? getDynamicSellTax() : sellTax;
    } else {
      return transferTax;
    }
  }

  function _shouldSwapBack(address recipient) private view returns (bool) {
    return isMarketMaker[recipient] && swapEnabled && balanceOf(address(this)) >= swapThreshold;
  }

  function _swapBack() private swapping {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = ROUTER.WETH();

    uint256 liquidityTokens = swapThreshold * liquidityShare / totalShares / 2;
    uint256 amountToSwap = swapThreshold - liquidityTokens;
    uint256 balanceBefore = address(this).balance;

    ROUTER.swapExactTokensForETH(
      amountToSwap,
      0,
      path,
      address(this),
      block.timestamp
    );

    uint256 amountBNB = address(this).balance - balanceBefore;
    uint256 totalBNBShares = totalShares - liquidityShare / 2;

    uint256 amountBNBLiquidity = amountBNB * liquidityShare / totalBNBShares / 2;
    uint256 amountBNBMarketing = amountBNB * marketingShare / totalBNBShares;
    uint256 amountBNBRewards = amountBNB * rewardShare / totalBNBShares;

    (bool marketingSuccess,) = payable(marketingWallet).call{value: amountBNBMarketing, gas: transferGas}("");
    if (marketingSuccess) { emit DepositMarketing(marketingWallet, amountBNBMarketing); }
    (bool rewardSuccess,) = payable(rewardWallet).call{value: amountBNBRewards, gas: transferGas}("");
    if (rewardSuccess) { emit DepositRewards(rewardWallet, amountBNBRewards); }

    if (liquidityTokens > 0) {
      ROUTER.addLiquidityETH{value: amountBNBLiquidity}(
        address(this),
        liquidityTokens,
        0,
        0,
        address(this),
        block.timestamp
      );

      emit AutoLiquidity(amountBNBLiquidity, liquidityTokens);
    }
  }

  // Owner

  function disableDumpProtection() external onlyOwner {
    dumpProtectionEnabled = false;
    emit DisableDumpProtection();
  }

  function removeSniperTax() external onlyOwner {
    sniperTax = false;
  }

  function enableTrading() external onlyOwner {
    tradingEnabled = true;
    launchTime = block.timestamp;
    emit EnableTrading();
  }

  function triggerSwapBack() external onlyOwner {
    _swapBack();
    emit TriggerSwapBack();
  }

  function recoverBNB() external onlyOwner {
    uint256 amount = address(this).balance;
    (bool sent,) = payable(marketingWallet).call{value: amount, gas: transferGas}("");
    require(sent, "Tx failed");
    emit RecoverBNB(amount);
  }

  function recoverBEP20(IBEP20 token, address recipient) external onlyOwner {
    require(address(token) != address(this), "Can't withdraw Step");
    uint256 amount = token.balanceOf(address(this));
    token.transfer(recipient, amount);
    emit RecoverBEP20(address(token), amount);
  }

  function setIsWhitelisted(address account, bool value) external onlyOwner {
    isWhitelisted[account] = value;
    emit SetWhitelisted(account, value);
  }

  function setIsCEX(address account, bool value) external onlyOwner {
    isCEX[account] = value;
    emit SetCEX(account, value);
  }

  function setIsMarketMaker(address account, bool value) external onlyOwner {
    require(account != pair, "Can't modify pair");
    isMarketMaker[account] = value;
    emit SetMarketMaker(account, value);
  }

  function setTaxes(uint256 newBuyTax, uint256 newSellTax, uint256 newTransferTax) external onlyOwner {
    require(newBuyTax <= 1500 && newSellTax <= 1500 && newTransferTax <= 1500, "Too high taxes");
    buyTax = newBuyTax;
    sellTax = newSellTax;
    transferTax = newTransferTax;
    emit SetTaxes(buyTax, sellTax, transferTax);
  }

  function setShares(uint256 newRewardShare, uint256 newLiquidityShare, uint256 newMarketingShare) external onlyOwner {
    rewardShare = newRewardShare;
    liquidityShare = newLiquidityShare;
    marketingShare = newMarketingShare;
    totalShares = rewardShare + liquidityShare + marketingShare;
    emit SetShares(rewardShare, liquidityShare, marketingShare);
  }

  function setSwapBackSettings(bool enabled, uint256 amount) external onlyOwner {
    uint256 tokenAmount = amount * 10**decimals();
    swapEnabled = enabled;
    swapThreshold = tokenAmount;
    emit SetSwapBackSettings(enabled, amount);
  }

  function setTransferGas(uint256 newGas) external onlyOwner {
    require(newGas >= 21000 && newGas <= 50000, "Invalid gas parameter");
    emit SetTransferGas(newGas, transferGas);
    transferGas = newGas;
  }

  function setMarketingWallet(address newWallet) external onlyOwner {
    require(newWallet != address(0), "New marketing wallet is the zero address");
    emit SetMarketingWallet(newWallet, marketingWallet);
    marketingWallet = newWallet;
  }

  function setRewardWallet(address newAddress) external onlyOwner {
    require(newAddress != address(0), "New reward pool is the zero address");
    emit SetRewardWallet(newAddress, rewardWallet);
    rewardWallet = newAddress;
  }
}
