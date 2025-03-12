pragma solidity =0.5.16;

import './interfaces/IFireBirdPair.sol';
import './interfaces/IFireBirdFormula.sol';
import './FireBirdERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IFireBirdFactory.sol';
import './interfaces/IUniswapV2Callee.sol';

contract FireBirdPair is IFireBirdPair, FireBirdERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint private unlocked = 1;
    address public formula;

    uint112 private collectedFee0;           // uses single storage slot, accessible via getReserves
    uint112 private collectedFee1;           // uses single storage slot, accessible via getReserves
    uint32 private tokenWeight0;

    uint32 private swapFee;

    modifier lock() {
        require(unlocked == 1, 'FLP: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function getCollectedFees() public view returns (uint112 _collectedFee0, uint112 _collectedFee1) {
        _collectedFee0 = collectedFee0;
        _collectedFee1 = collectedFee1;
    }

    function getTokenWeights() public view returns (uint32 _tokenWeight0, uint32 _tokenWeight1) {
        _tokenWeight0 = tokenWeight0;
        _tokenWeight1 = 100 - tokenWeight0;
    }

    function getSwapFee() public view returns (uint32 _swapFee) {
        _swapFee = swapFee;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'FLP: TRANSFER_FAILED');
    }

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1, uint32 _tokenWeight0, uint32 _swapFee) external {
        require(msg.sender == factory, 'FLP: FORBIDDEN');
        // sufficient check
        token0 = _token0;
        token1 = _token1;
        tokenWeight0 = _tokenWeight0;
        swapFee = _swapFee;
        formula = IFireBirdFactory(factory).formula();
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        uint32 _tokenWeight0 = tokenWeight0;
        require(balance0 * (100 - _tokenWeight0) <= uint112(- 1) && balance1 * _tokenWeight0 <= uint112(- 1), 'FLP: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            uint112 mReserve0 = _reserve0 * (100 - _tokenWeight0);
            uint112 mReserve1 = _reserve1 * _tokenWeight0;
            price0CumulativeLast += uint(UQ112x112.encode(mReserve1).uqdiv(mReserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(mReserve0).uqdiv(mReserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IFireBirdFactory(factory).feeTo();
        uint112 protocolFee = uint112(IFireBirdFactory(factory).protocolFee());
        feeOn = feeTo != address(0);
        (uint112 _collectedFee0, uint112 _collectedFee1) = getCollectedFees();
        if (protocolFee > 0 && feeOn && (_collectedFee0 > 0 || _collectedFee1 > 0)) {
            uint32 _tokenWeight0 = tokenWeight0;
            uint liquidity = IFireBirdFormula(formula).mintLiquidityFee(
                totalSupply, _reserve0, _reserve1,
                _tokenWeight0, 100 - _tokenWeight0,
                _collectedFee0 / protocolFee, _collectedFee1 / protocolFee
            );
            if (liquidity > 0) _mint(feeTo, liquidity);
        }
        if (_collectedFee0 > 0) collectedFee0 = 0;
        if (_collectedFee1 > 0) collectedFee1 = 0;
    }
    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);
        _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
            // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'FLP: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];
        _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply;// using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply;// using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'FLP: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }
    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'FLP: INSUFFICIENT_OUTPUT_AMOUNT');
        uint112 _reserve0 = reserve0; // gas savings
        uint112 _reserve1 = reserve1; // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'FLP: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'FLP: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'FLP: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(10000);
            uint balance1Adjusted = balance1.mul(10000);
            { // avoids stack too deep errors
                if (amount0In > 0) {
                    uint amount0InFee = amount0In.mul(swapFee);
                    balance0Adjusted = balance0Adjusted.sub(amount0InFee);
                    collectedFee0 = uint112(uint(collectedFee0).add(amount0InFee));
                }
                if (amount1In > 0) {
                    uint amount1InFee = amount1In.mul(swapFee);
                    balance1Adjusted = balance1Adjusted.sub(amount1InFee);
                    collectedFee1 = uint112(uint(collectedFee1).add(amount1InFee));
                }
                uint32 _tokenWeight0 = tokenWeight0;// gas savings
                if (_tokenWeight0 == 50) { // gas savings for pair 50/50
                    require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000**2), 'FLP: K');
                } else {
                    require(IFireBirdFormula(formula).ensureConstantValue(uint(_reserve0).mul(10000), uint(_reserve1).mul(10000), balance0Adjusted, balance1Adjusted, _tokenWeight0), 'FLP: K');
                }
            }
        }
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
