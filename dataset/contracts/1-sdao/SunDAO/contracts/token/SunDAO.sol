// SPDX-License-Identifier: Unlicensed
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IUniswapV2Factory {
  function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;

  function factory() external pure returns (address);

  function WETH() external pure returns (address);
}

interface BPContract {
  function protect(
    address from,
    address to,
    uint256 amount
  ) external;
}

contract SunDAO is Context, IERC20, Ownable {
  using SafeMath for uint256;
  using Address for address;

  mapping(address => uint256) private _rOwned;
  mapping(address => uint256) private _tOwned;
  mapping(address => mapping(address => uint256)) private _allowances;

  mapping(address => bool) private _isExcludedFromFee;

  uint256 private constant MAX = ~uint256(0);
  uint256 private _tTotal = 10**10 * 10**9;
  uint256 private _rTotal = (MAX - (MAX % _tTotal));
  uint256 private _tFeeTotal;

  uint256 public developmentFee = 2;
  uint256 public marketingFee = 2;
  uint256 public burnFee = 2;
  uint256 public fees = developmentFee + marketingFee + burnFee;
  uint256 public taxFee = 3;

  uint256 private _fees;
  uint256 private _taxFee;

  string private _name = "SunDAO";
  string private _symbol = "SDAO";
  uint8 private _decimals = 9;

  address payable private _developmentAddress = payable(0x3BA72Af3F2B41b4fcb632f0E68b7dffA0F0F5027);
  address payable private _marketingAddress = payable(0x7b152099f6bc4E00e2Fb0E21AD5F1a32979D700e);

  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;

  bool private inSwap = false;

  event UpdateDevelopmentAddress(address indexed oldAddress, address indexed newAddress);
  event UpdateMarketingAddress(address indexed oldAddress, address indexed newAddress);

  modifier lockTheSwap() {
    inSwap = true;
    _;
    inSwap = false;
  }

  modifier onlyGovernor() {
    require(
      _msgSender() == owner() || _msgSender() == _developmentAddress || _msgSender() == _marketingAddress,
      "onlyGovernor: caller is not the governor"
    );
    _;
  }

  constructor() public {
    _rOwned[_msgSender()] = _rTotal;
    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    uniswapV2Router = _uniswapV2Router;
    uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

    _isExcludedFromFee[owner()] = true;
    _isExcludedFromFee[address(this)] = true;
    _isExcludedFromFee[_developmentAddress] = true;
    _isExcludedFromFee[_marketingAddress] = true;

    emit Transfer(address(0), _msgSender(), _tTotal);
  }

  receive() external payable {}

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view override returns (uint256) {
    return _tTotal;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return tokenFromReflection(_rOwned[account]);
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) public view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) public override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(
      sender,
      _msgSender(),
      _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")
    );
    return true;
  }

  function totalFees() public view returns (uint256) {
    return _tFeeTotal;
  }

  function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
    require(rAmount <= _rTotal, "tokenFromReflection: amount must be less than total reflections");
    uint256 currentRate = _getRate();
    return rAmount.div(currentRate);
  }

  function _getValues(uint256 tAmount)
    private
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    (uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getTValues(tAmount);
    (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tTeam, _getRate());
    return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tTeam);
  }

  function _getTValues(uint256 tAmount)
    private
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    uint256 tFee = tAmount.mul(_taxFee).div(100);
    uint256 tTeam = tAmount.mul(_fees).div(100);
    uint256 tTransferAmount = tAmount.sub(tFee).sub(tTeam);
    return (tTransferAmount, tFee, tTeam);
  }

  function _getRValues(
    uint256 tAmount,
    uint256 tFee,
    uint256 tTeam,
    uint256 currentRate
  )
    private
    pure
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    uint256 rAmount = tAmount.mul(currentRate);
    uint256 rFee = tFee.mul(currentRate);
    uint256 rTeam = tTeam.mul(currentRate);
    uint256 rTransferAmount = rAmount.sub(rFee).sub(rTeam);
    return (rAmount, rTransferAmount, rFee);
  }

  function _getRate() private view returns (uint256) {
    (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
    return rSupply.div(tSupply);
  }

  function _reflectFee(uint256 rFee, uint256 tFee) private {
    _rTotal = _rTotal.sub(rFee);
    _tFeeTotal = _tFeeTotal.add(tFee);
  }

  function _takeTeam(uint256 tTeam) private {
    uint256 currentRate = _getRate();
    uint256 rTeam = tTeam.mul(currentRate);
    uint256 rBurn = rTeam.mul(burnFee).div(fees);
    _rOwned[address(this)] = _rOwned[address(this)].add(rTeam.sub(rBurn));
    _rOwned[address(0)] = _rOwned[address(0)].add(rBurn);
  }

  function _getCurrentSupply() private view returns (uint256, uint256) {
    return (_rTotal, _tTotal);
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) private {
    require(owner != address(0), "_approve: approve from the zero address");
    require(spender != address(0), "_approve: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) private {
    require(from != address(0), "_transfer: transfer from the zero address");
    require(to != address(0), "_transfer: transfer to the zero address");
    require(amount > 0, "_transfer: transfer amount must be greater than zero");
    _beforeTokenTransfer(from, to, amount);

    _fees = 0;
    _taxFee = 0;

    uint256 contractTokenBalance = balanceOf(address(this));
    if (!inSwap && from != uniswapV2Pair && contractTokenBalance > 0) {
      swapTokensForETH(contractTokenBalance);
      uint256 contractETHBalance = address(this).balance;
      if (contractETHBalance > 0) {
        sendETHToFee(contractETHBalance);
      }
    }

    if (from == uniswapV2Pair || to == uniswapV2Pair) {
      _fees = fees;
      _taxFee = taxFee;
    }
    if ((_isExcludedFromFee[from] || _isExcludedFromFee[to]) || (from != uniswapV2Pair && to != uniswapV2Pair)) {
      _fees = 0;
      _taxFee = 0;
    }
    _tokenTransfer(from, to, amount);
  }

  function swapTokensForETH(uint256 tokenAmount) private lockTheSwap {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0,
      path,
      address(this),
      block.timestamp
    );
  }

  function sendETHToFee(uint256 amount) private {
    uint256 totalFee = developmentFee.add(marketingFee);
    uint256 developmentAmount = amount.mul(developmentFee).div(totalFee);
    (bool success, ) = _developmentAddress.call{ value: developmentAmount }("");
    require(success, "sendETHToFee: revert");
    (success, ) = _marketingAddress.call{ value: amount.sub(developmentAmount) }("");
    require(success, "sendETHToFee: revert");
  }

  function _tokenTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) private {
    _transferStandard(sender, recipient, amount);
  }

  function _transferStandard(
    address sender,
    address recipient,
    uint256 tAmount
  ) private {
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rFee,
      uint256 tTransferAmount,
      uint256 tFee,
      uint256 tTeam
    ) = _getValues(tAmount);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    _takeTeam(tTeam);
    _reflectFee(rFee, tFee);
    emit Transfer(sender, recipient, tTransferAmount);
  }

  function manualSwap() external onlyGovernor {
    swapTokensForETH(balanceOf(address(this)));
  }

  function manualSend() external onlyGovernor {
    sendETHToFee(address(this).balance);
  }

  function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyGovernor {
    for (uint256 i = 0; i < accounts.length; i++) {
      _isExcludedFromFee[accounts[i]] = excluded;
    }
  }

  function setNewDevelopmentAddress(address payable newAddress) public onlyGovernor {
    emit UpdateDevelopmentAddress(_developmentAddress, newAddress);
    _developmentAddress = newAddress;
    _isExcludedFromFee[newAddress] = true;
  }

  function setNewMarketingAddress(address payable newAddress) public onlyGovernor {
    emit UpdateMarketingAddress(_marketingAddress, newAddress);
    _marketingAddress = newAddress;
    _isExcludedFromFee[newAddress] = true;
  }

  BPContract public bp;
  bool public bpEnabled;

  function setBPAddress(address _bp) external onlyGovernor {
    bp = BPContract(_bp);
  }

  function setBPEnabled(bool _enabled) external onlyGovernor {
    bpEnabled = _enabled;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual {
    if (bpEnabled) {
      bp.protect(from, to, amount);
    }
  }
}
