//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import './interface/IUniswapV2Pair.sol';
import './interface/IUniswapV2Factory.sol';
import './interface/IUniswapV2Router.sol';

contract FullRestore is ERC20, Ownable {
  using SafeMath for uint256;

  IUniswapV2Router02 public uniswapV2Router;
  address public uniswapV2Pair;

  string private _name = 'Full Restore';
  string private _symbol = 'FULL';
  uint8 private _decimals = 9;
  uint256 private _totalSupply = 1000000000 * 10**9;

  bool private inSwapAndLiquify;
  mapping(address => bool) excluded;
  mapping(address => bool) public blacklist;
  uint256 private sellCount;
  bool private prevSell;

  uint256 public buyLiquidityFee = 300; // 3%
  uint256 public sellLiquidityFee = 600; // 6%
  uint256 public buyCharityFee = 100; // 1%
  uint256 public sellCharityFee = 100; // 1%
  uint256 public buyBurnFee = 50; // 0.5%
  uint256 public sellBurnFee = 50; // 0.5%
  uint256 public buyDevFee = 50; // 0.5%
  uint256 public sellDevFee = 50; // 0.5%
  uint256 public doubleSellCount = 7;
  uint256 public doubleSellAmount = 5000000 * 10**9;
  uint256 public maxBuyAmount = 10000000 * 10**9;

  address public charityAddress =
    address(0x62aFEbB34b92d5f24117785a0147F6Bb3275A1B7);
  address public devAddress =
    address(0xEBdC249284a90B5A30e7b1c5DE2466aa79408F18);

  modifier lockTheSwap() {
    inSwapAndLiquify = true;
    _;
    inSwapAndLiquify = false;
  }

  constructor(address _routerAddr) public ERC20(_name, _symbol) {
    _setupDecimals(_decimals);

    excluded[msg.sender] = true;

    updateUniswapV2Router(_routerAddr);

    _mint(msg.sender, _totalSupply);
  }

  //to recieve ETH from uniswapV2Router when swaping
  receive() external payable {}

  function updateUniswapV2Router(address _addr) public onlyOwner {
    require(_addr != address(0), 'zero address');

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_addr);

    // Create a uniswap pair for this new token
    uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
      address(this),
      _uniswapV2Router.WETH()
    );

    // set the rest of the contract variables
    uniswapV2Router = _uniswapV2Router;
  }

  function excludeFromFee(address _addr) external onlyOwner {
    require(_addr != address(0), 'zero address is not allowed');
    excluded[_addr] = true;
  }

  function includeFromFee(address _addr) external onlyOwner {
    require(_addr != address(0), 'zero address is not allowed');
    excluded[_addr] = false;
  }

  function isExcludedFromFee(address _addr) public view returns (bool) {
    return excluded[_addr];
  }

  function updateBuyLiquidityFee(uint256 _fee) external onlyOwner {
    buyLiquidityFee = _fee;
  }

  function updateSellLiquidityFee(uint256 _fee) external onlyOwner {
    sellLiquidityFee = _fee;
  }

  function updateBuyCharityFee(uint256 _fee) external onlyOwner {
    buyCharityFee = _fee;
  }

  function updateSellCharityFee(uint256 _fee) external onlyOwner {
    sellCharityFee = _fee;
  }

  function updateBuyBurnFee(uint256 _fee) external onlyOwner {
    buyBurnFee = _fee;
  }

  function updateSellBurnFee(uint256 _fee) external onlyOwner {
    sellBurnFee = _fee;
  }

  function updateBuyDevFee(uint256 _fee) external onlyOwner {
    buyDevFee = _fee;
  }

  function updateSellDevFee(uint256 _fee) external onlyOwner {
    sellDevFee = _fee;
  }

  function setCharityAddress(address _addr) external onlyOwner {
    charityAddress = _addr;
  }

  function setDevAddress(address _addr) external onlyOwner {
    devAddress = _addr;
  }

  function updateDoubleSellCount(uint256 _count) external onlyOwner {
    doubleSellCount = _count;
  }

  function updateDoubleSellAmount(uint256 _amount) external onlyOwner {
    doubleSellAmount = _amount;
  }

  function updateMaxBuyAmount(uint256 _amount) external onlyOwner {
    maxBuyAmount = _amount;
  }

  function updateBlacklist(address account, bool res) external onlyOwner {
    blacklist[account] = res;
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    _tokenTransfer(_msgSender(), recipient, amount);

    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _tokenTransfer(sender, recipient, amount);

    _approve(
      sender,
      _msgSender(),
      allowance(sender, _msgSender()).sub(
        amount,
        'ERC20: transfer amount exceeds allowance'
      )
    );
    return true;
  }

  function _tokenTransfer(
    address from,
    address to,
    uint256 amount
  ) private {
    require(from != address(0), 'ERC20: transfer from the zero address');
    require(to != address(0), 'ERC20: transfer to the zero address');
    require(amount > 0, 'Transfer amount must be greater than zero');
    require(!blacklist[from], 'Sender blacklisted');
    require(!blacklist[to], 'Recipient blacklisted');

    uint256 contractTokenBalance = balanceOf(address(this));

    if (
      contractTokenBalance > 0 &&
      !inSwapAndLiquify &&
      from != address(uniswapV2Router) &&
      to == uniswapV2Pair &&
      !isExcludedFromFee(from)
    ) {
      swapAndDistribute(contractTokenBalance);
    }

    if (
      !inSwapAndLiquify &&
      (from == uniswapV2Pair || to == uniswapV2Pair) &&
      !isExcludedFromFee(from) &&
      !isExcludedFromFee(to)
    ) {
      uint256 swapFee = 0;
      uint256 burnFee = 0;

      if (to == uniswapV2Pair) {
        // Sell
        prevSell = true;
        swapFee = sellDevFee.add(sellCharityFee.add(sellLiquidityFee));
        burnFee = sellBurnFee;
        sellCount = sellCount + 1;
        if (amount >= doubleSellAmount) {
          sellCount = doubleSellCount;
        }
        if (sellCount >= doubleSellCount) {
          swapFee = swapFee.mul(2);
          burnFee = burnFee.mul(2);
        }
      } else {
        require(amount <= maxBuyAmount, 'Over the max buy amount');
        prevSell = false;
        swapFee = buyDevFee.add(buyCharityFee.add(buyLiquidityFee));
        if (sellCount >= doubleSellCount) {
          swapFee = swapFee.div(2);
          burnFee = burnFee.div(2);
        }
        sellCount = 0;
      }

      uint256 swapAmount = amount.mul(swapFee).div(10**4);
      uint256 burnAmount = amount.mul(burnFee).div(10**4);
      uint256 remainingAmount = amount.sub(swapAmount).sub(burnAmount);

      if (burnAmount > 0) {
        _burn(from, burnAmount);
      }
      if (swapAmount > 0) {
        _transfer(from, address(this), swapAmount);
      }
      _transfer(from, to, remainingAmount);
    } else {
      _transfer(from, to, amount);
    }
  }

  function swapAndDistribute(uint256 tokenAmount) private lockTheSwap {
    uint256 charityFee = 0;
    uint256 liquidityFee = 0;
    uint256 devFee = 0;

    if (prevSell) {
      charityFee = sellCharityFee;
      liquidityFee = sellLiquidityFee;
      devFee = sellDevFee;
    } else {
      charityFee = buyCharityFee;
      liquidityFee = buyLiquidityFee;
      devFee = buyDevFee;
    }

    uint256 totalFee = charityFee.add(liquidityFee).add(devFee);
    liquidityFee = liquidityFee.div(2);
    uint256 liquidityAmount = tokenAmount.mul(liquidityFee).div(totalFee);

    swapTokensForEth(tokenAmount.sub(liquidityAmount));

    uint256 amountETH = address(this).balance;
    if (amountETH > 0) {
      totalFee = charityFee.add(liquidityFee).add(devFee);
      uint256 liqETH = amountETH.mul(liquidityFee).div(totalFee);
      uint256 charityETH = amountETH.mul(charityFee).div(totalFee);
      uint256 devETH = amountETH.sub(liqETH).sub(charityETH);

      addLiquidity(liquidityAmount, liqETH);
      payable(charityAddress).call{value: charityETH}('');
      payable(devAddress).call{value: devETH}('');
    }
  }

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
    uniswapV2Router.addLiquidityETH{value: ethAmount}(
      address(this),
      tokenAmount,
      0, // slippage is unavoidable
      0, // slippage is unavoidable
      owner(),
      block.timestamp
    );
  }
}
