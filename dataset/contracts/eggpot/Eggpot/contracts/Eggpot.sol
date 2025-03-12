// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import './utils/Context.sol';
import './utils/EnumerableSet.sol';
import './interface/IERC20.sol';
import './token/ERC20.sol';
import './access/Ownable.sol';
import './interface/IUniswapV2Router02.sol';
import './interface/IUniswapV2Factory.sol';
import './interface/IUniswapV2Pair.sol';

contract Eggpot is ERC20, Ownable {
  uint256 public maxBuyAmount;
  uint256 public maxSellAmount;
  uint256 public maxWalletAmount;

  address[] public buyerList;
  uint256 public timeBetweenBuysForJackpot = 10 minutes;
  uint256 public numberOfBuysForJackpot = 10;
  uint256 public minBuyAmount = .1 ether;
  bool public minBuyEnforced = true;
  uint256 public percentForJackpot = 50;
  bool public jackpotEnabled = true;
  uint256 public lastBuyTimestamp;

  IUniswapV2Router02 public dexRouter;
  address public lpPair;

  bool private swapping;
  uint256 public swapTokensAtAmount;

  address operationsAddress;

  uint256 public tradingActiveBlock = 0;
  mapping(address => bool) public restrictedWallet;
  uint256 public botsCaught;

  bool public limitsInEffect = true;
  bool public tradingActive = false;
  bool public swapEnabled = false;

  uint256 public buyTotalFees;
  uint256 public buyOperationsFee;
  uint256 public buyLiquidityFee;
  uint256 public buyJackpotFee;

  uint256 public originalSellOperationsFee;
  uint256 public originalSellLiquidityFee;
  uint256 public originalSellJackpotFee;

  uint256 public sellTotalFees;
  uint256 public sellOperationsFee;
  uint256 public sellLiquidityFee;
  uint256 public sellJackpotFee;

  uint256 public tokensForOperations;
  uint256 public tokensForLiquidity;
  uint256 public tokensForJackpot;

  uint256 public constant FEE_DENOMINATOR = 10000;

  mapping(address => bool) public _isExcludedFromFees;
  mapping(address => bool) public _isExcludedMaxTransactionAmount;

  mapping(address => bool) public automatedMarketMakerPairs;

  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

  event EnabledTrading();

  event EnabledLimits();

  event RemovedLimits();

  event DisabledJeetTaxes();

  event ExcludeFromFees(address indexed account, bool isExcluded);

  event UpdatedMaxBuyAmount(uint256 newAmount);

  event UpdatedMaxSellAmount(uint256 newAmount);

  event UpdatedMaxWalletAmount(uint256 newAmount);

  event UpdatedOperationsAddress(address indexed newWallet);

  event MaxTransactionExclusion(address _address, bool excluded);

  event BuyBackTriggered(uint256 amount);

  event OwnerForcedSwapBack(uint256 timestamp);

  event CaughtBot(address sniper);

  event TransferForeignToken(address token, uint256 amount);

  event JackpotTriggered(uint256 indexed amount, address indexed wallet);

  constructor() payable ERC20('Eggpot', 'EGGPOT') {
    address newOwner = msg.sender;

    dexRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // dexRouter = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);

    lpPair = IUniswapV2Factory(dexRouter.factory()).createPair(
      address(this),
      dexRouter.WETH()
    );
    _excludeFromMaxTransaction(address(lpPair), true);
    _setAutomatedMarketMakerPair(address(lpPair), true);

    operationsAddress = address(0x96fADA4e4e823570F3eE8B678DD3314E31858894);

    uint256 totalSupply = 1 * 1e9 * 1e18;

    maxBuyAmount = (totalSupply * 4) / 1000; // 0.4%
    maxSellAmount = (totalSupply * 4) / 1000; // 0.4%
    maxWalletAmount = (totalSupply * 55) / 10000; // 0.55%
    swapTokensAtAmount = (totalSupply * 20) / 100000; // 0.020%

    buyOperationsFee = 0;
    buyLiquidityFee = 0;
    buyJackpotFee = 0;
    buyTotalFees = buyOperationsFee + buyLiquidityFee + buyJackpotFee;

    originalSellOperationsFee = 400;
    originalSellLiquidityFee = 0;
    originalSellJackpotFee = 700;

    sellOperationsFee = 500;
    sellLiquidityFee = 0;
    sellJackpotFee = 1000;
    sellTotalFees = sellOperationsFee + sellLiquidityFee + sellJackpotFee;

    _excludeFromMaxTransaction(newOwner, true);
    _excludeFromMaxTransaction(msg.sender, true);
    _excludeFromMaxTransaction(operationsAddress, true);
    _excludeFromMaxTransaction(address(this), true);
    _excludeFromMaxTransaction(address(0xdead), true);
    _excludeFromMaxTransaction(address(dexRouter), true);

    excludeFromFees(newOwner, true);
    excludeFromFees(msg.sender, true);
    excludeFromFees(operationsAddress, true);
    excludeFromFees(address(this), true);
    excludeFromFees(address(0xdead), true);
    excludeFromFees(address(dexRouter), true);

    _createInitialSupply(newOwner, totalSupply); // Tokens for liquidity

    transferOwnership(newOwner);
  }

  receive() external payable {}

  // only use if conducting a presale
  function addPresaleAddressForExclusions(address _presaleAddress)
    external
    onlyOwner
  {
    excludeFromFees(_presaleAddress, true);
    _excludeFromMaxTransaction(_presaleAddress, true);
  }

  function enableTrading() external onlyOwner {
    swapEnabled = true;
    tradingActive = true;
    tradingActiveBlock = block.number;
    lastBuyTimestamp = block.timestamp;
    emit EnabledTrading();
  }

  // remove limits after token is stable
  function removeLimits() external onlyOwner {
    limitsInEffect = false;
    emit RemovedLimits();
  }

  function enableLimits() external onlyOwner {
    limitsInEffect = true;
    emit EnabledLimits();
  }

  function setJackpotEnabled(bool enabled) external onlyOwner {
    jackpotEnabled = enabled;
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

  function updateMaxWallet(uint256 newNum) external onlyOwner {
    require(newNum >= ((totalSupply() * 25) / 10000) / (10**decimals()));
    maxWalletAmount = newNum * (10**decimals());
    emit UpdatedMaxWalletAmount(maxWalletAmount);
  }

  // change the minimum amount of tokens to sell from fees
  function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
    require(newAmount >= (totalSupply() * 1) / 100000);
    require(newAmount <= (totalSupply() * 1) / 1000);
    swapTokensAtAmount = newAmount;
  }

  function _excludeFromMaxTransaction(address updAds, bool isExcluded) private {
    _isExcludedMaxTransactionAmount[updAds] = isExcluded;
    emit MaxTransactionExclusion(updAds, isExcluded);
  }

  function airdropToWallets(
    address[] memory wallets,
    uint256[] memory amountsInTokens
  ) external onlyOwner {
    require(wallets.length == amountsInTokens.length);
    require(wallets.length < 600); // allows for airdrop + launch at the same exact time, reducing delays and reducing sniper input.
    for (uint256 i = 0; i < wallets.length; i++) {
      super._transfer(msg.sender, wallets[i], amountsInTokens[i]);
    }
  }

  function setNumberOfBuysForJackpot(uint256 num) external onlyOwner {
    require(
      num >= 2 && num <= 100,
      'Must keep number of buys between 2 and 100'
    );
    numberOfBuysForJackpot = num;
  }

  function excludeFromMaxTransaction(address updAds, bool isEx)
    external
    onlyOwner
  {
    if (!isEx) {
      require(updAds != lpPair, 'Cannot remove uniswap pair from max txn');
    }
    _isExcludedMaxTransactionAmount[updAds] = isEx;
  }

  function setAutomatedMarketMakerPair(address pair, bool value)
    external
    onlyOwner
  {
    require(
      pair != lpPair,
      'The pair cannot be removed from automatedMarketMakerPairs'
    );

    _setAutomatedMarketMakerPair(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function _setAutomatedMarketMakerPair(address pair, bool value) private {
    automatedMarketMakerPairs[pair] = value;

    _excludeFromMaxTransaction(pair, value);

    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function updateBuyFees(
    uint256 _operationsFee,
    uint256 _liquidityFee,
    uint256 _jackpotFee
  ) external onlyOwner {
    buyOperationsFee = _operationsFee;
    buyLiquidityFee = _liquidityFee;
    buyJackpotFee = _jackpotFee;
    buyTotalFees = buyOperationsFee + buyLiquidityFee + buyJackpotFee;
    require(buyTotalFees <= 1500, 'Must keep fees at 15% or less');
  }

  function updateSellFees(
    uint256 _operationsFee,
    uint256 _liquidityFee,
    uint256 _jackpotFee
  ) external onlyOwner {
    sellOperationsFee = _operationsFee;
    sellLiquidityFee = _liquidityFee;
    sellJackpotFee = _jackpotFee;
    sellTotalFees = sellOperationsFee + sellLiquidityFee + sellJackpotFee;
    require(sellTotalFees <= 2000, 'Must keep fees at 20% or less');
  }

  function disableJeetTaxes() external onlyOwner {
    sellOperationsFee = originalSellOperationsFee;
    sellLiquidityFee = originalSellLiquidityFee;
    sellJackpotFee = originalSellJackpotFee;
    sellTotalFees = sellOperationsFee + sellLiquidityFee + sellJackpotFee;

    emit DisabledJeetTaxes();
  }

  function excludeFromFees(address account, bool excluded) public onlyOwner {
    _isExcludedFromFees[account] = excluded;
    emit ExcludeFromFees(account, excluded);
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    require(from != address(0), 'ERC20: transfer from the zero address');
    require(to != address(0), 'ERC20: transfer to the zero address');
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
          require(amount + balanceOf(to) <= maxWalletAmount);
        }
        //when sell
        else if (
          automatedMarketMakerPairs[to] &&
          !_isExcludedMaxTransactionAmount[from]
        ) {
          require(amount <= maxSellAmount);
        } else if (!_isExcludedMaxTransactionAmount[to]) {
          require(amount + balanceOf(to) <= maxWalletAmount);
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
    // if any account belongs to _isExcludedFromFee account then remove the fee
    if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
      takeFee = false;
    }

    uint256 fees = 0;

    if (takeFee) {
      // sell
      if (
        automatedMarketMakerPairs[to] &&
        !_isExcludedMaxTransactionAmount[from] &&
        sellTotalFees > 0
      ) {
        fees = (amount * (sellTotalFees)) / FEE_DENOMINATOR;
        tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
        tokensForOperations += (fees * sellOperationsFee) / sellTotalFees;
        tokensForJackpot += (fees * sellJackpotFee) / sellTotalFees;
      }
      // buy
      else if (
        automatedMarketMakerPairs[from] &&
        !_isExcludedMaxTransactionAmount[to] &&
        buyTotalFees > 0
      ) {
        if (jackpotEnabled) {
          if (
            block.timestamp >= lastBuyTimestamp + timeBetweenBuysForJackpot &&
            address(this).balance > 0.1 ether &&
            buyerList.length >= numberOfBuysForJackpot
          ) {
            payoutRewards(to);
          } else {
            gasBurn();
          }
        }

        if (!minBuyEnforced || amount > getPurchaseAmount()) {
          buyerList.push(to);
        }

        lastBuyTimestamp = block.timestamp;

        if (buyTotalFees > 0) {
          fees = (amount * (buyTotalFees)) / FEE_DENOMINATOR;
          tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
          tokensForOperations += (fees * buyOperationsFee) / buyTotalFees;
          tokensForJackpot += (fees * buyJackpotFee) / buyTotalFees;
        }
      }

      if (fees > 0) {
        super._transfer(from, address(this), fees);
      }

      amount -= fees;
    }

    super._transfer(from, to, amount);
  }

  function getPurchaseAmount() public view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = dexRouter.WETH();
    path[1] = address(this);

    uint256[] memory amounts = new uint256[](2);
    amounts = dexRouter.getAmountsOut(minBuyAmount, path);
    return amounts[1];
  }

  // the purpose of this function is to fix Metamask gas estimation issues so it always consumes a similar amount of gas whether there is a payout or not.
  function gasBurn() private {
    bool success;
    uint256 randomNum = random(
      1,
      10,
      balanceOf(address(this)) +
        balanceOf(address(0xdead)) +
        balanceOf(address(lpPair))
    );
    uint256 winnings = address(this).balance / 2;
    address winner = address(this);
    winnings = 0;
    randomNum = 0;
    (success, ) = address(winner).call{ value: winnings }('');
    require(success, 'Failure! fund not sent');
  }

  function payoutRewards(address to) private {
    bool success;
    // get a pseudo random winner
    uint256 randomNum = random(
      1,
      numberOfBuysForJackpot,
      balanceOf(address(this)) +
        balanceOf(address(0xdead)) +
        balanceOf(address(to))
    );
    address winner = buyerList[buyerList.length - randomNum];
    uint256 winnings = (address(this).balance * percentForJackpot) / 100;
    (success, ) = address(winner).call{ value: winnings }('');
    require(success, 'Failure! fund not sent');

    if (success) {
      emit JackpotTriggered(winnings, winner);
    }
    delete buyerList;
  }

  function random(
    uint256 from,
    uint256 to,
    uint256 salty
  ) private view returns (uint256) {
    uint256 seed = uint256(
      keccak256(
        abi.encodePacked(
          block.timestamp +
            block.difficulty +
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) /
              (block.timestamp)) +
            block.gaslimit +
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) /
              (block.timestamp)) +
            block.number +
            salty
        )
      )
    );
    return (seed % (to - from)) + from;
  }

  function updateJackpotTimeCooldown(uint256 timeInMinutes) external onlyOwner {
    require(timeInMinutes > 0 && timeInMinutes <= 360);
    timeBetweenBuysForJackpot = timeInMinutes * 1 minutes;
  }

  function updatePercentForJackpot(uint256 percent) external onlyOwner {
    require(percent >= 10 && percent <= 100);
    percentForJackpot = percent;
  }

  function updateMinBuyToTriggerReward(uint256 minBuy) external onlyOwner {
    minBuyAmount = minBuy;
  }

  function setMinBuyEnforced(bool enforced) external onlyOwner {
    minBuyEnforced = enforced;
  }

  function swapTokensForEth(uint256 tokenAmount) private {
    // generate the uniswap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = dexRouter.WETH();

    _approve(address(this), address(dexRouter), tokenAmount);

    // make the swap
    dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0, // accept any amount of ETH
      path,
      address(this),
      block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    // approve token transfer to cover all possible scenarios
    _approve(address(this), address(dexRouter), tokenAmount);

    // add the liquidity
    dexRouter.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      0, // slippage is unavoidable
      0, // slippage is unavoidable
      address(0xdead),
      block.timestamp
    );
  }

  function swapBack() private {
    uint256 contractBalance = balanceOf(address(this));
    uint256 totalTokensToSwap = tokensForLiquidity +
      tokensForOperations +
      tokensForJackpot;

    if (contractBalance == 0 || totalTokensToSwap == 0) {
      return;
    }

    if (contractBalance > swapTokensAtAmount * 10) {
      contractBalance = swapTokensAtAmount * 10;
    }

    bool success;

    // Halve the amount of liquidity tokens
    uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
      totalTokensToSwap /
      2;

    uint256 initialBalance = address(this).balance;
    swapTokensForEth(contractBalance - liquidityTokens);

    uint256 ethBalance = address(this).balance - initialBalance;
    uint256 ethForLiquidity = ethBalance;

    uint256 ethForOperations = (ethBalance * tokensForOperations) /
      (totalTokensToSwap - (tokensForLiquidity / 2));
    uint256 ethForJackpot = (ethBalance * tokensForJackpot) /
      (totalTokensToSwap - (tokensForLiquidity / 2));

    ethForLiquidity -= ethForOperations + ethForJackpot;

    tokensForLiquidity = 0;
    tokensForOperations = 0;
    tokensForJackpot = 0;

    if (liquidityTokens > 0 && ethForLiquidity > 0) {
      addLiquidity(liquidityTokens, ethForLiquidity);
    }

    if (ethForOperations > 0) {
      (success, ) = address(operationsAddress).call{ value: ethForOperations }(
        ''
      );
      require(success, 'Failure! fund not sent');
    }
    // remaining ETH stays for Jackpot
  }

  function transferForeignToken(address _token, address _to)
    external
    onlyOwner
    returns (bool _sent)
  {
    require(_token != address(0));
    require(_token != address(this));
    uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
    _sent = IERC20(_token).transfer(_to, _contractBalance);
    emit TransferForeignToken(_token, _contractBalance);
  }

  // withdraw ETH
  function withdrawStuckETH() external onlyOwner {
    bool success;
    (success, ) = address(owner()).call{ value: address(this).balance }('');
    require(success, 'Failure! fund not sent');
  }

  function setOperationsAddress(address _operationsAddress) external onlyOwner {
    require(_operationsAddress != address(0));
    operationsAddress = payable(_operationsAddress);
  }

  // force Swap back if slippage issues.
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

  function getBuyerListLength() external view returns (uint256) {
    return buyerList.length;
  }
}
