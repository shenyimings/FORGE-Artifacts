// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "./access/Ownable.sol";
import "./token/ERC20/ERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";

/**
 * Style In App Token
 * @author STYLIKE
 */

contract StylikeToken is ERC20, Ownable {

  IUniswapV2Router02 public uniswapV2Router;
  address public  uniswapV2Pair;

  address operationsAddress;

  uint256 public constant FEE_DENOMINATOR = 10000;
  uint256 public minBuyAmount = .1 ether;

  uint256 public maxBuyAmount;
  uint256 public maxSellAmount;

  uint256 public buyTotalFees;
  uint256 public buyOperationsFee;
  uint256 public buyLiquidityFee;

  uint256 public sellTotalFees;
  uint256 public sellOperationsFee;
  uint256 public sellLiquidityFee;

  uint256 public originalSellOperationsFee;
  uint256 public originalSellLiquidityFee;

  uint256 public tokensForOperations;
  uint256 public tokensForLiquidity;

  bool private swapping;
  bool public minBuyEnforced = true;

  bool public swapEnabled = true;
  bool public tradingActive = false;
  bool public limitsInEffect = true;

  uint256 public swapTokensAtAmount;

  mapping (address => bool) private _isExcludedFromFees;
  mapping(address => bool) public _isExcludedMaxTransactionAmount;

  mapping (address => bool) public automatedMarketMakerPairs;

  event ExcludeFromFees(address indexed account, bool isExcluded);
  event IncludedInFee(address indexed account);
  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
  event MaxTransactionExclusion(address _address, bool excluded);
  event DisabledJeetTaxes();
  event UpdatedMaxSellAmount(uint256 newAmount);
  event UpdatedMaxBuyAmount(uint256 newAmount);
  event OwnerForcedSwapBack(uint256 timestamp);
  event EnabledTrading();
  event EnabledSwap();
  event EnabledLimits();
  event RemovedLimits();

  constructor () ERC20("Stylike Governance", "STYL"){

    operationsAddress = address(0x9DF601a3f7402e6d6B34B6E33F2B256A954F3431);

    // mainnet
    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    
    //testnet
    // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);

    address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

    uniswapV2Router = _uniswapV2Router;
    uniswapV2Pair   = _uniswapV2Pair;

    _approve(address(this), address(uniswapV2Router), type(uint256).max);

    _excludeFromMaxTransaction(uniswapV2Pair, true);
    _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

    uint256 totalSupply = 1 * 1e9 * 1e18;

    maxBuyAmount = (totalSupply * 4) / 1000; // 0.4%
    maxSellAmount = (totalSupply * 4) / 1000; // 0.4%
    swapTokensAtAmount = (totalSupply * 20) / 10000000; // 0.00020%

    buyOperationsFee = 500;
    buyLiquidityFee = 0;
    buyTotalFees = buyOperationsFee + buyLiquidityFee;

    sellLiquidityFee = 0;
    sellOperationsFee = 500;
    sellTotalFees = sellOperationsFee + sellLiquidityFee;

    originalSellOperationsFee = 0;
    originalSellLiquidityFee = 0;

    _excludeFromMaxTransaction(owner(), true);
    _excludeFromMaxTransaction(operationsAddress, true);
    _excludeFromMaxTransaction(address(this), true);
    _excludeFromMaxTransaction(address(0xdead), true);
    _excludeFromMaxTransaction(address(uniswapV2Router), true);

    excludeFromFees(owner(), true);
    excludeFromFees(address(0xdead), true);
    excludeFromFees(operationsAddress, true);
    excludeFromFees(address(this), true);

    _mint(owner(),totalSupply);

  }

  receive() external payable {}

  function setAutomatedMarketMakerPair(address pair, bool value)
    external
    onlyOwner
  {
    require(
      pair != uniswapV2Pair,
      'The pair cannot be removed from automatedMarketMakerPairs'
    );

    _setAutomatedMarketMakerPair(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function _setAutomatedMarketMakerPair(address pair, bool value) private {
      require(automatedMarketMakerPairs[pair] != value, "Automated market maker pair is already set to that value");
      automatedMarketMakerPairs[pair] = value;

      emit SetAutomatedMarketMakerPair(pair, value);
  }

  function excludeFromFees(address account, bool excluded) public onlyOwner {
    _isExcludedFromFees[account] = excluded;
    emit ExcludeFromFees(account, excluded);
  }

  function addPresaleAddressForExclusions(address _presaleAddress)
    external
    onlyOwner
  {
    excludeFromFees(_presaleAddress, true);
    _excludeFromMaxTransaction(_presaleAddress, true);
  }

  function includeInFee(address account) external onlyOwner {
      require(_isExcludedFromFees[account] != false, "Account is already the value of 'excluded'");
      _isExcludedFromFees[account] = false;

      emit IncludedInFee(account);
  }

  function isExcludedFromFees(address account) public view returns(bool) {
      return _isExcludedFromFees[account];
  }

  function disableJeetTaxes() external onlyOwner {
    sellOperationsFee = originalSellOperationsFee;
    sellLiquidityFee = originalSellLiquidityFee;
    sellTotalFees = sellOperationsFee + sellLiquidityFee;

    emit DisabledJeetTaxes();
  }

  function updateSellFees(
    uint256 _operationsFee,
    uint256 _liquidityFee
  ) external onlyOwner {
    sellOperationsFee = _operationsFee;
    sellLiquidityFee = _liquidityFee;
    sellTotalFees = sellOperationsFee + sellLiquidityFee;
    require(sellTotalFees <= 2000, 'Must keep fees at 20% or less');
  }

  function updateBuyFees(
    uint256 _operationsFee,
    uint256 _liquidityFee
  ) external onlyOwner {
    buyOperationsFee = _operationsFee;
    buyLiquidityFee = _liquidityFee;
    buyTotalFees = buyOperationsFee + buyLiquidityFee;
    require(buyTotalFees <= 1000, 'Must keep fees at 10% or less');
  }

  function _excludeFromMaxTransaction(address updAds, bool isExcluded) private {
    _isExcludedMaxTransactionAmount[updAds] = isExcluded;
    emit MaxTransactionExclusion(updAds, isExcluded);
  }

  // transfer
  function _transfer(
      address from,
      address to,
      uint256 amount
  ) internal  override {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, 'ERC20: transfer must be greater than 0');

    if (!tradingActive) {
      require(
        _isExcludedFromFees[from] || _isExcludedFromFees[to],
        'Trading is not active.'
      );
    }

    if (limitsInEffect) {
      if (
        from != owner() &&
        to != owner() &&
        to != address(0) &&
        to != address(0xdead) &&
        !_isExcludedFromFees[from] &&
        !_isExcludedFromFees[to]
      ) {
        //when buy
        if (
          automatedMarketMakerPairs[from] &&
          !_isExcludedMaxTransactionAmount[to]
        ) {
          require(amount <= maxBuyAmount);
        }
        //when sell
        else if (
          automatedMarketMakerPairs[to] &&
          !_isExcludedMaxTransactionAmount[from]
        ) {
          require(amount <= maxSellAmount);
        } 
      }
    }

    uint256 contractTokenBalance = balanceOf(address(this));

    bool canSwap = contractTokenBalance >= swapTokensAtAmount;

    if (
      canSwap &&
      swapEnabled &&
      !swapping &&
      !automatedMarketMakerPairs[from] &&
      !_isExcludedFromFees[from] &&
      !_isExcludedFromFees[to]
    ) {
      swapping = true;
      swapBack();
      swapping = false;
    }

    bool takeFee = true;

    if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
      takeFee = false;
    }

    uint256 fees = 0;

    if (takeFee) {
      // sell
      if (
        automatedMarketMakerPairs[to] &&
        automatedMarketMakerPairs[from] &&
        sellTotalFees > 0
      ) {
        fees = (amount * (sellTotalFees)) / FEE_DENOMINATOR;
        tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
        tokensForOperations += (fees * sellOperationsFee) / sellTotalFees;
      }
      // buy
      else if (
        automatedMarketMakerPairs[from] &&
        !automatedMarketMakerPairs[to] &&
        buyTotalFees > 0
      ) {
          fees = (amount * (buyTotalFees)) / FEE_DENOMINATOR;
          tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
          tokensForOperations += (fees * buyOperationsFee) / buyTotalFees;
      }

      if (fees > 0) {
        super._transfer(from, address(this), fees);
      }

      amount -= fees;
    }

    super._transfer(from, to, amount);

  }

  // liquidity
  function swapTokensForEth(uint256 tokenAmount) private {
    // generate the uniswap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();

    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // make the swap
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0, // accept any amount of ETH
      path,
      address(this),
      block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    // approve token transfer to cover all possible scenarios
    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // add the liquidity
    uniswapV2Router.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      0, // slippage is unavoidable
      0, // slippage is unavoidable
      address(0xdead),
      block.timestamp
    );
  }

  function changeSwapStatus(bool _enabled) external onlyOwner {
      swapEnabled = _enabled;
  }

  function setSwapTokensAtAmount(uint256 newAmount) external onlyOwner{
      require(newAmount > totalSupply() / 1000000, "SwapTokensAtAmount must be greater than 0.0001% of total supply");
      swapTokensAtAmount = newAmount;
  }

  function getPurchaseAmount() public view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = uniswapV2Router.WETH();
    path[1] = address(this);

    uint256[] memory amounts = new uint256[](2);
    amounts = uniswapV2Router.getAmountsOut(minBuyAmount, path);
    return amounts[1];
  }

 function swapBack() private {
    uint256 contractBalance = balanceOf(address(this));
    uint256 totalTokensToSwap = tokensForLiquidity + tokensForOperations;

    if (contractBalance == 0 || totalTokensToSwap == 0) {
      return;
    }

    if (contractBalance > swapTokensAtAmount * 10) {
      contractBalance = swapTokensAtAmount * 10;
    }

    bool success;

    // Halve the amount of liquidity tokens
    uint256 liquidityTokens = (contractBalance * tokensForLiquidity) / totalTokensToSwap / 2;

    uint256 initialBalance = address(this).balance;
    swapTokensForEth(contractBalance - liquidityTokens);

    uint256 ethBalance = address(this).balance - initialBalance;
    uint256 ethForLiquidity = ethBalance;

    uint256 ethForOperations = (ethBalance * tokensForOperations) /
      (totalTokensToSwap - (tokensForLiquidity / 2));

    ethForLiquidity -= ethForOperations;

    tokensForLiquidity = 0;
    tokensForOperations = 0;

    if (liquidityTokens > 0 && ethForLiquidity > 0) {
      addLiquidity(liquidityTokens, ethForLiquidity);
    }

    if (ethForOperations > 0) {
      (success, ) = address(operationsAddress).call{ value: ethForOperations }('');
      require(success, 'Failure! fund not sent');
    }
  }

  function enableTrading() external onlyOwner {
    tradingActive = true;
    emit EnabledTrading();
  }

  function enableSwap() external onlyOwner {
    swapEnabled = true;
    emit EnabledSwap();
  }

  function removeLimits() external onlyOwner {
    limitsInEffect = false;
    emit RemovedLimits();
  }

  function enableLimits() external onlyOwner {
    limitsInEffect = true;
    emit EnabledLimits();
  }

  function claimStuckTokens(address token) external onlyOwner {
      require(token != address(this), "Owner cannot claim native tokens");
      if (token == address(0x0)) {
          payable(msg.sender).transfer(address(this).balance);
          return;
      }
      IERC20 ERC20token = IERC20(token);
      uint256 balance = ERC20token.balanceOf(address(this));
      ERC20token.transfer(msg.sender, balance);
  }

  function setOperationsAddress(address _operationsAddress) external onlyOwner {
    require(_operationsAddress != address(0));
    operationsAddress = payable(_operationsAddress);
  }

  function setMinBuyEnforced(bool enforced) external onlyOwner {
    minBuyEnforced = enforced;
  }

  function forceSwapBack() external onlyOwner {
    require(
      balanceOf(address(this)) >= swapTokensAtAmount,
      'Can only swap when token amount is at or higher than restriction'
    );
    swapping = true;
    swapBack();
    swapping = false;
    emit OwnerForcedSwapBack(block.timestamp);
  }

  function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
    require(newAmount >= (totalSupply() * 1) / 100000);
    require(newAmount <= (totalSupply() * 1) / 1000);
    swapTokensAtAmount = newAmount;
  }

  function updateMaxBuyAmount(uint256 newNum) external onlyOwner {
    require(newNum >= ((totalSupply() * 25) / 10000) / (10**decimals()));
    maxBuyAmount = newNum * (10**decimals());
    emit UpdatedMaxBuyAmount(maxBuyAmount);
  }

  function updateMaxSellAmount(uint256 newNum) external onlyOwner {
    require(newNum >= ((totalSupply() * 25) / 10000) / (10**decimals()));
    maxSellAmount = newNum * (10**decimals());
    emit UpdatedMaxSellAmount(maxSellAmount);
  }

  function updateMinBuyToTriggerReward(uint256 minBuy) external onlyOwner {
    minBuyAmount = minBuy;
  }

}

