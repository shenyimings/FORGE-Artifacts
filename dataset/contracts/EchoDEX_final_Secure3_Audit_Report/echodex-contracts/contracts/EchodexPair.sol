// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.6.6;

import './EchodexERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IEchodexFactory.sol';
import './interfaces/IEchodexCallee.sol';
import './interfaces/IxECP.sol';

contract EchodexPair is EchodexERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    uint private constant  FEE_DENOMINATOR = 10000;
    uint private constant MAX_PAY_DEFAULT_PERCENT = 30; // 0.3%
    uint private constant MAX_PAY_WITH_TOKEN_FEE_PERCENT = 10; // 0.1%

    address public immutable factory;
    address public token0;
    address public token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;

    uint public totalFee;
    uint public currentFee;

    struct SwapState {
        uint balance0;
        uint balance1;
        uint amount0In;
        uint amount1In;
        uint112 _reserve0;
        uint112 _reserve1;
    }

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Echodex: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Echodex: TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to,
        uint amountTokenFee,
        uint amountTokenReward
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event AddFee(uint amount);

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'Echodex: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'Echodex: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // pay fee
    function _payFee(uint fee) private { //payWithTokenFee = true
        address tokenFee = IEchodexFactory(factory).tokenFee();
        address receiveFeeAddress = IEchodexFactory(factory).receiveFeeAddress();
        require(currentFee >= fee, 'Echodex: INSUFFICIENT_FEE_TOKEN');

        currentFee = currentFee - fee;
        _safeTransfer(tokenFee, receiveFeeAddress, fee);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        address tokenFee = IEchodexFactory(factory).tokenFee();

        if (token0 == tokenFee) {
            balance0 = balance0.sub(currentFee);
        }

        if (token1 == tokenFee) {
            balance1 = balance1.sub(currentFee);
        }

        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'Echodex: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        address tokenFee = IEchodexFactory(factory).tokenFee();
        if (token0 == tokenFee) {
            balance0 = balance0.sub(currentFee);
        }

        if (token1 == tokenFee) {
            balance1 = balance1.sub(currentFee);
        }

        uint liquidity = balanceOf[address(this)];

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'Echodex: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        if (token0 == tokenFee) {
            balance0 = balance0.sub(currentFee);
        }

        if (token1 == tokenFee) {
            balance1 = balance1.sub(currentFee);
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function _preSwap(uint amount0Out, uint amount1Out, address to) private view returns(SwapState memory state){
        require(amount0Out > 0 || amount1Out > 0, 'Echodex: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Echodex: INSUFFICIENT_LIQUIDITY');
        state = SwapState({
            balance0: 0,
            balance1: 0,
            amount0In: 0,
            amount1In: 0,
            _reserve0: _reserve0,
            _reserve1: _reserve1
        });

        require(to != token0 && to != token1, 'Echodex: INVALID_TO');
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock { // payWithTokenFee = false
        SwapState memory state = _preSwap(amount0Out, amount1Out, to);

        uint amountOut = amount0Out > 0 ? amount0Out : amount1Out;
        address tokenOut = amount0Out > 0 ? token0 : token1;
        uint fee = amountOut.mul(MAX_PAY_DEFAULT_PERCENT) / FEE_DENOMINATOR;

        // calc reward
        uint rewardPercent = IEchodexFactory(factory).rewardPercent(address(this));
        uint amountTokenReward = 0;
        if(rewardPercent > 0 && IEchodexFactory(factory).feePathLength(tokenOut) > 0) {
            amountTokenReward = IEchodexFactory(factory).calcFeeOrReward(tokenOut, amountOut, rewardPercent);
            IxECP(IEchodexFactory(factory).tokenReward()).mintReward(to, amountTokenReward);
        }

        _safeTransfer(tokenOut, to, amountOut.sub(fee));
        _safeTransfer(tokenOut, IEchodexFactory(factory).receiveFeeAddress(), fee);

        if (data.length > 0){
            if(amount0Out>0){
                IEchodexCallee(to).echodexCall(msg.sender, amountOut.sub(fee), amount1Out, data);
            }else if(amount1Out>0){
                IEchodexCallee(to).echodexCall(msg.sender, amount0Out, amountOut.sub(fee), data);
            }
        }
        state.balance0 = IERC20(token0).balanceOf(address(this));
        state.balance1 = IERC20(token1).balanceOf(address(this));

        {   // avoids stack too deep errors
            address tokenFee = IEchodexFactory(factory).tokenFee();
            if (token0 == tokenFee) {
            state.balance0 = state.balance0.sub(currentFee);
            }

            if (token1 == tokenFee) {
                state.balance1 = state.balance1.sub(currentFee);
            }
        }

        state.amount0In = state.balance0 > state._reserve0 - amount0Out ? state.balance0 - (state._reserve0 - amount0Out) : 0;
        state.amount1In = state.balance1 > state._reserve1 - amount1Out ? state.balance1 - (state._reserve1 - amount1Out) : 0;
        require(state.amount0In > 0 || state.amount1In > 0, 'Echodex: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            require(state.balance0.mul(state.balance1) >= uint(state._reserve0).mul(state._reserve1), 'Echodex: K');
        }

        _update(state.balance0, state.balance1, state._reserve0, state._reserve1);
        emit Swap(msg.sender, state.amount0In, state.amount1In, amount0Out, amount1Out, to, 0, amountTokenReward);
    }

    function swapPayWithTokenFee(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock { // payWithTokenFee = true
        SwapState memory state = _preSwap(amount0Out, amount1Out, to);

        uint amountOut = amount0Out > 0 ? amount0Out : amount1Out;
        address tokenOut = amount0Out > 0 ? token0 : token1;

        //fee
        uint fee = IEchodexFactory(factory).calcFeeOrReward(tokenOut, amountOut, MAX_PAY_WITH_TOKEN_FEE_PERCENT); // 0.1%
        _payFee(fee);
        _safeTransfer(tokenOut, to, amountOut);

        if (data.length > 0) IEchodexCallee(to).echodexCall(msg.sender, amount0Out, amount1Out, data);
        state.balance0 = IERC20(token0).balanceOf(address(this));
        state.balance1 = IERC20(token1).balanceOf(address(this));

        address tokenFee = IEchodexFactory(factory).tokenFee();
        if (token0 == tokenFee) {
            state.balance0 = state.balance0.sub(currentFee);
        }

        if (token1 == tokenFee) {
            state.balance1 = state.balance1.sub(currentFee);
        }

        state.amount0In = state.balance0 > state._reserve0 - amount0Out ? state.balance0 - (state._reserve0 - amount0Out) : 0;
        state.amount1In = state.balance1 > state._reserve1 - amount1Out ? state.balance1 - (state._reserve1 - amount1Out) : 0;
        require(state.amount0In > 0 || state.amount1In > 0, 'Echodex: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        require(state.balance0.mul(state.balance1) >= uint(state._reserve0).mul(state._reserve1), 'Echodex: K');
        }
        _update(state.balance0, state.balance1, state._reserve0, state._reserve1);
        emit Swap(msg.sender, state.amount0In, state.amount1In, amount0Out, amount1Out, to, fee, 0);
    }

    function addFee(uint amount) external lock {
        address tokenFee = IEchodexFactory(factory).tokenFee();
        IERC20(tokenFee).transferFrom(msg.sender, address(this), amount);
        totalFee = totalFee + amount;
        currentFee = currentFee + amount;

        emit AddFee(amount);
    }

    function withdrawFee(uint amount) external lock {
        address owner = IEchodexFactory(factory).owner();
        require(owner == msg.sender, "Echodex: FORBIDDEN");
        require(amount <= currentFee, "Echodex: INSUFFICIENT_INPUT_AMOUNT");

        address tokenFee = IEchodexFactory(factory).tokenFee();
        address receiveFeeAddress = IEchodexFactory(factory).receiveFeeAddress();
        totalFee = totalFee - amount;
        currentFee = currentFee - amount;

        _safeTransfer(tokenFee, receiveFeeAddress, amount);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        address tokenFee = IEchodexFactory(factory).tokenFee();
        if (_token0 == tokenFee) {
            balance0 = balance0.sub(currentFee);
        }

        if (_token1 == tokenFee) {
            balance1 = balance1.sub(currentFee);
        }

        _safeTransfer(_token0, to, balance0.sub(reserve0));
        _safeTransfer(_token1, to, balance1.sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        address tokenFee = IEchodexFactory(factory).tokenFee();
        if (token0 == tokenFee) {
            balance0 = balance0.sub(currentFee);
        }

        if (token1 == tokenFee) {
            balance1 = balance1.sub(currentFee);
        }

        _update(balance0, balance1, reserve0, reserve1);
    }
}