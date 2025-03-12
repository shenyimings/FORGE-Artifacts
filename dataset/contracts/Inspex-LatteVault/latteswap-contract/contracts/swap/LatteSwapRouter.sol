// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import './libraries/LatteSwapLibrary.sol';
import './libraries/LatteSwapSafeMath.sol';
import './libraries/TransferHelper.sol';
import './interfaces/ILatteSwapRouter.sol';
import './interfaces/ILatteSwapFactory.sol';
import './interfaces/ILatteSwapBEP20.sol';
import './interfaces/IWBNB.sol';

contract LatteSwapRouter is ILatteSwapRouter {
  using LatteSwapSafeMath for uint;

  address public immutable override factory;
  address public immutable override WBNB;

  modifier ensure(uint deadline) {
    require(deadline >= block.timestamp, 'LatteSwapRouter::ensure::EXPIRED');
    _;
  }

  constructor(address _factory, address _WBNB) public {
    factory = _factory;
    WBNB = _WBNB;
  }

  receive() external payable {
    assert(msg.sender == WBNB); // only accept ETH via fallback from the WBNB contract
  }

  // **** ADD LIQUIDITY ****
  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin
  ) internal virtual returns (uint amountA, uint amountB) {
    // create the pair if it doesn't exist yet
    if (ILatteSwapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
      ILatteSwapFactory(factory).createPair(tokenA, tokenB);
    }
    (uint reserveA, uint reserveB) = LatteSwapLibrary.getReserves(factory, tokenA, tokenB);
    if (reserveA == 0 && reserveB == 0) {
      (amountA, amountB) = (amountADesired, amountBDesired);
    } else {
      uint amountBOptimal = LatteSwapLibrary.quote(amountADesired, reserveA, reserveB);
      if (amountBOptimal <= amountBDesired) {
        require(amountBOptimal >= amountBMin, 'LatteSwapRouter::_addLiquidity::INSUFFICIENT_B_AMOUNT');
        (amountA, amountB) = (amountADesired, amountBOptimal);
      } else {
        uint amountAOptimal = LatteSwapLibrary.quote(amountBDesired, reserveB, reserveA);
        assert(amountAOptimal <= amountADesired);
        require(amountAOptimal >= amountAMin, 'LatteSwapRouter::_addLiquidity::INSUFFICIENT_A_AMOUNT');
        (amountA, amountB) = (amountAOptimal, amountBDesired);
      }
    }
  }

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
    (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
    address pair = LatteSwapLibrary.pairFor(factory, tokenA, tokenB);
    TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
    TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
    liquidity = ILatteSwapPair(pair).mint(to);
  }

  function addLiquidityETH(
    address token,
    uint amountTokenDesired,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
    (amountToken, amountETH) = _addLiquidity(
      token,
      WBNB,
      amountTokenDesired,
      msg.value,
      amountTokenMin,
      amountETHMin
    );
    address pair = LatteSwapLibrary.pairFor(factory, token, WBNB);
    TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
    IWBNB(WBNB).deposit{value: amountETH}();
    assert(IWBNB(WBNB).transfer(pair, amountETH));
    liquidity = ILatteSwapPair(pair).mint(to);
    // refund dust eth, if any
    if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
  }

  // **** REMOVE LIQUIDITY ****
  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
    address pair = LatteSwapLibrary.pairFor(factory, tokenA, tokenB);
    ILatteSwapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
    (uint amount0, uint amount1) = ILatteSwapPair(pair).burn(to);
    (address token0,) = LatteSwapLibrary.sortTokens(tokenA, tokenB);
    (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
    require(amountA >= amountAMin, 'LatteSwapRouter::removeLiquidity::INSUFFICIENT_A_AMOUNT');
    require(amountB >= amountBMin, 'LatteSwapRouter::removeLiquidity::INSUFFICIENT_B_AMOUNT');
  }

  function removeLiquidityETH(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
    (amountToken, amountETH) = removeLiquidity(
      token,
      WBNB,
      liquidity,
      amountTokenMin,
      amountETHMin,
      address(this),
      deadline
    );
    TransferHelper.safeTransfer(token, to, amountToken);
    IWBNB(WBNB).withdraw(amountETH);
    TransferHelper.safeTransferETH(to, amountETH);
  }

  function removeLiquidityWithPermit(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline,
    bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external virtual override returns (uint amountA, uint amountB) {
    address pair = LatteSwapLibrary.pairFor(factory, tokenA, tokenB);
    uint value = approveMax ? uint(-1) : liquidity;
    ILatteSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
  }

  function removeLiquidityETHWithPermit(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline,
    bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external virtual override returns (uint amountToken, uint amountETH) {
    address pair = LatteSwapLibrary.pairFor(factory, token, WBNB);
    uint value = approveMax ? uint(-1) : liquidity;
    ILatteSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
  }

  // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
  function removeLiquidityETHSupportingFeeOnTransferTokens(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) public virtual override ensure(deadline) returns (uint amountETH) {
    (, amountETH) = removeLiquidity(
      token,
      WBNB,
      liquidity,
      amountTokenMin,
      amountETHMin,
      address(this),
      deadline
    );
    TransferHelper.safeTransfer(token, to, ILatteSwapBEP20(token).balanceOf(address(this)));
    IWBNB(WBNB).withdraw(amountETH);
    TransferHelper.safeTransferETH(to, amountETH);
  }

  function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline,
    bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external virtual override returns (uint amountETH) {
    address pair = LatteSwapLibrary.pairFor(factory, token, WBNB);
    uint value = approveMax ? uint(-1) : liquidity;
    ILatteSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
      token, liquidity, amountTokenMin, amountETHMin, to, deadline
    );
  }

  // **** SWAP ****
  // requires the initial amount to have already been sent to the first pair
  function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
    for (uint i; i < path.length - 1; i++) {
      (address input, address output) = (path[i], path[i + 1]);
      (address token0,) = LatteSwapLibrary.sortTokens(input, output);
      uint amountOut = amounts[i + 1];
      (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
      address to = i < path.length - 2 ? LatteSwapLibrary.pairFor(factory, output, path[i + 2]) : _to;
      ILatteSwapPair(LatteSwapLibrary.pairFor(factory, input, output)).swap(
        amount0Out, amount1Out, to, new bytes(0)
      );
    }
  }

  function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    amounts = LatteSwapLibrary.getAmountsOut(factory, amountIn, path);
    require(amounts[amounts.length - 1] >= amountOutMin, 'LatteSwapRouter::swapExactTokensForTokens::INSUFFICIENT_OUTPUT_AMOUNT');
    TransferHelper.safeTransferFrom(
      path[0], msg.sender, LatteSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
    );
    _swap(amounts, path, to);
  }

  function swapTokensForExactTokens(
    uint amountOut,
    uint amountInMax,
    address[] calldata path,
    address to,
    uint deadline
  ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    amounts = LatteSwapLibrary.getAmountsIn(factory, amountOut, path);
    require(amounts[0] <= amountInMax, 'LatteSwapRouter::swapTokensForExactTokens::EXCESSIVE_INPUT_AMOUNT');
    TransferHelper.safeTransferFrom(
      path[0], msg.sender, LatteSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
    );
    _swap(amounts, path, to);
  }

  function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    virtual
    override
    payable
    ensure(deadline)
    returns (uint[] memory amounts)
  {
    require(path[0] == WBNB, 'LatteSwapRouter::swapExactETHForTokens::INVALID_PATH');
    amounts = LatteSwapLibrary.getAmountsOut(factory, msg.value, path);
    require(amounts[amounts.length - 1] >= amountOutMin, 'LatteSwapRouter::swapExactETHForTokens::INSUFFICIENT_OUTPUT_AMOUNT');
    IWBNB(WBNB).deposit{value: amounts[0]}();
    assert(IWBNB(WBNB).transfer(LatteSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
    _swap(amounts, path, to);
  }

  function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    virtual
    override
    ensure(deadline)
    returns (uint[] memory amounts)
  {
    require(path[path.length - 1] == WBNB, 'LatteSwapRouter::swapTokensForExactETH::INVALID_PATH');
    amounts = LatteSwapLibrary.getAmountsIn(factory, amountOut, path);
    require(amounts[0] <= amountInMax, 'LatteSwapRouter::swapTokensForExactETH::EXCESSIVE_INPUT_AMOUNT');
    TransferHelper.safeTransferFrom(
        path[0], msg.sender, LatteSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
    );
    _swap(amounts, path, address(this));
    IWBNB(WBNB).withdraw(amounts[amounts.length - 1]);
    TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
  }

  function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    virtual
    override
    ensure(deadline)
    returns (uint[] memory amounts)
  {
    require(path[path.length - 1] == WBNB, 'LatteSwapRouter::swapExactTokensForETH::INVALID_PATH');
    amounts = LatteSwapLibrary.getAmountsOut(factory, amountIn, path);
    require(amounts[amounts.length - 1] >= amountOutMin, 'LatteSwapRouter:swapExactTokensForETH::INSUFFICIENT_OUTPUT_AMOUNT');
    TransferHelper.safeTransferFrom(
        path[0], msg.sender, LatteSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
    );
    _swap(amounts, path, address(this));
    IWBNB(WBNB).withdraw(amounts[amounts.length - 1]);
    TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
  }

  function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    virtual
    override
    payable
    ensure(deadline)
    returns (uint[] memory amounts)
  {
    require(path[0] == WBNB, 'LatteSwapRouter::swapETHForExactTokens::INVALID_PATH');
    amounts = LatteSwapLibrary.getAmountsIn(factory, amountOut, path);
    require(amounts[0] <= msg.value, 'LatteSwapRouter::swapETHForExactTokens::EXCESSIVE_INPUT_AMOUNT');
    IWBNB(WBNB).deposit{value: amounts[0]}();
    assert(IWBNB(WBNB).transfer(LatteSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
    _swap(amounts, path, to);
    // refund dust eth, if any
    if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
  }

  // **** SWAP (supporting fee-on-transfer tokens) ****
  // requires the initial amount to have already been sent to the first pair
  function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
    for (uint i; i < path.length - 1; i++) {
      (address input, address output) = (path[i], path[i + 1]);
      (address token0,) = LatteSwapLibrary.sortTokens(input, output);
      ILatteSwapPair pair = ILatteSwapPair(LatteSwapLibrary.pairFor(factory, input, output));
      uint amountInput;
      uint amountOutput;
      { // scope to avoid stack too deep errors
      (uint reserve0, uint reserve1,) = pair.getReserves();
      (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
      amountInput = ILatteSwapBEP20(input).balanceOf(address(pair)).sub(reserveInput);
      amountOutput = LatteSwapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
      }
      (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
      address to = i < path.length - 2 ? LatteSwapLibrary.pairFor(factory, output, path[i + 2]) : _to;
      pair.swap(amount0Out, amount1Out, to, new bytes(0));
    }
  }

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
      uint amountIn,
      uint amountOutMin,
      address[] calldata path,
      address to,
      uint deadline
  ) external virtual override ensure(deadline) {
    TransferHelper.safeTransferFrom(
      path[0], msg.sender, LatteSwapLibrary.pairFor(factory, path[0], path[1]), amountIn
    );
    uint balanceBefore = ILatteSwapBEP20(path[path.length - 1]).balanceOf(to);
    _swapSupportingFeeOnTransferTokens(path, to);
    require(
      ILatteSwapBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
      'LatteSwapRouter::swapExactTokensForTokensSupportingFeeOnTransferTokens::INSUFFICIENT_OUTPUT_AMOUNT'
    );
  }

  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  )
    external
    virtual
    override
    payable
    ensure(deadline)
  {
    require(path[0] == WBNB, 'LatteSwapRouter::swapExactETHForTokensSupportingFeeOnTransferTokens::INVALID_PATH');
    uint amountIn = msg.value;
    IWBNB(WBNB).deposit{value: amountIn}();
    assert(IWBNB(WBNB).transfer(LatteSwapLibrary.pairFor(factory, path[0], path[1]), amountIn));
    uint balanceBefore = ILatteSwapBEP20(path[path.length - 1]).balanceOf(to);
    _swapSupportingFeeOnTransferTokens(path, to);
    require(
      ILatteSwapBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
      'LatteSwapRouter::swapExactETHForTokensSupportingFeeOnTransferTokens::INSUFFICIENT_OUTPUT_AMOUNT'
    );
  }

  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  )
    external
    virtual
    override
    ensure(deadline)
  {
    require(path[path.length - 1] == WBNB, 'LatteSwapRouter::swapExactTokensForETHSupportingFeeOnTransferTokens::INVALID_PATH');
    TransferHelper.safeTransferFrom(
        path[0], msg.sender, LatteSwapLibrary.pairFor(factory, path[0], path[1]), amountIn
    );
    _swapSupportingFeeOnTransferTokens(path, address(this));
    uint amountOut = ILatteSwapBEP20(WBNB).balanceOf(address(this));
    require(amountOut >= amountOutMin, 'LatteSwapRouter::swapExactTokensForETHSupportingFeeOnTransferTokens::INSUFFICIENT_OUTPUT_AMOUNT');
    IWBNB(WBNB).withdraw(amountOut);
    TransferHelper.safeTransferETH(to, amountOut);
  }

  // **** LIBRARY FUNCTIONS ****
  function quote(uint amountA, uint reserveA, uint reserveB) external pure virtual override returns (uint amountB) {
    return LatteSwapLibrary.quote(amountA, reserveA, reserveB);
  }

  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
    external
    pure
    virtual
    override
    returns (uint amountOut)
  {
    return LatteSwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
  }

  function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
    external
    pure
    virtual
    override
    returns (uint amountIn)
  {
    return LatteSwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
  }

  function getAmountsOut(uint amountIn, address[] memory path)
    external
    view
    virtual
    override
    returns (uint[] memory amounts)
  {
    return LatteSwapLibrary.getAmountsOut(factory, amountIn, path);
  }

  function getAmountsIn(uint amountOut, address[] memory path)
    external
    view
    virtual
    override
    returns (uint[] memory amounts)
  {
    return LatteSwapLibrary.getAmountsIn(factory, amountOut, path);
  }
}