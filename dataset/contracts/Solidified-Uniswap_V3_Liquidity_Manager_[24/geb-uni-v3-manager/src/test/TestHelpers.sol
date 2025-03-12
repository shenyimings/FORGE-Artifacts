pragma solidity 0.6.7;

import "../../lib/ds-test/src/test.sol";
import "../GebUniswapV3ManagerBase.sol";
import "../uni/UniswapV3Factory.sol";
import "../uni/UniswapV3Pool.sol";
import "../erc20/ERC20.sol";

// --- Token Contracts ---
contract TestToken is ERC20 {
    constructor(string memory _symbol, uint256 supply) public ERC20(_symbol, _symbol) {
        _mint(msg.sender, supply);
    }

    function mintTo(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }
    function mint(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }
    function burn(address _recipient, uint256 _amount) public {
        _burn(_recipient, _amount);
    }
}

contract TestRAI is TestToken {
    constructor(string memory _symbol) public TestToken(_symbol, 12000000000000000 ether) {}
}

contract TestWETH is TestToken {
    constructor(string memory _symbol) public TestToken(_symbol, 300000000 ether) {}

    fallback() external payable {
        deposit();
    }
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }
    function withdraw(uint wad) public {   
        _burn(msg.sender,wad);
        msg.sender.transfer(wad);
    }
}

abstract contract Hevm {
    function warp(uint256) public virtual;
    function roll(uint256) public virtual;
}

contract PoolUser {
    GebUniswapV3ManagerBase manager;
    TestToken rai;
    TestToken weth;
    UniswapV3Pool pool;

    constructor(
        GebUniswapV3ManagerBase man,
        UniswapV3Pool _pool,
        TestToken _r,
        TestToken _w
    ) public {
        pool = _pool;
        manager = man;
        rai = _r;
        weth = _w;
    }

    receive() external payable {
    }

    function doTransfer(
        address token,
        address to,
        uint256 amount
    ) public {
        ERC20(token).transfer(to, amount);
    }

    function doDeposit(uint128 liquidityAmount) public payable{
        manager.deposit{value:msg.value}(liquidityAmount, address(this), 0, 0);
    }

    function doDepositWithSlippage(uint128 liquidityAmount, uint256 minAm0, uint256 minAm1) public payable{
        manager.deposit{value:msg.value}(liquidityAmount, address(this), minAm0, minAm1);
    }

    function doWithdraw(uint128 liquidityAmount) public returns (uint256 amount0, uint256 amount1) {
        uint128 max_uint128 = uint128(0 - 1);
        (amount0, amount1) = manager.withdraw(liquidityAmount, address(this));
    }

    function doApprove(
        address token,
        address who,
        uint256 amount
    ) public {
        IERC20(token).approve(who, amount);
    }

    function doMint(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) public {
        pool.mint(address(this), _tickLower, _tickUpper, _amount, new bytes(0));
    }

    function doBurn(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) public {
        pool.burn(_tickLower, _tickUpper, _amount);
    }

    function doCollectFromPool(
        int24 lowerTick,
        int24 upperTick,
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) public {
        pool.collect(recipient, lowerTick, upperTick, amount0Requested, amount1Requested);
    }

    function doSwap(
        bool _zeroForOne,
        int256 _amountSpecified,
        uint160 _sqrtPriceLimitX96
    ) public {
        pool.swap(address(this), _zeroForOne, _amountSpecified, _sqrtPriceLimitX96, new bytes(0));
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (address(pool.token0()) == address(rai)) {
            if (amount0Delta > 0) rai.transfer(msg.sender, uint256(amount0Delta));
            if (amount1Delta > 0) weth.transfer(msg.sender, uint256(amount1Delta));
        } else {
            if (amount1Delta > 0) rai.transfer(msg.sender, uint256(amount1Delta));
            if (amount0Delta > 0) weth.transfer(msg.sender, uint256(amount0Delta));
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        if (address(pool.token0()) == address(rai)) {
            rai.transfer(msg.sender, amount0Owed);
            weth.transfer(msg.sender, amount1Owed);
        } else {
            rai.transfer(msg.sender, amount1Owed);
            weth.transfer(msg.sender, amount0Owed);
        }
    }

    function doArbitrary(address target, bytes calldata data) external {
        (bool succ, ) = target.call(data);
        require(succ, "call failed");
    }
}
