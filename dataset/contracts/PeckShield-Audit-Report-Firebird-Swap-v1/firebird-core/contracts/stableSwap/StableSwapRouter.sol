pragma solidity =0.6.12;

import '../interfaces/ISwap.sol';

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract StableSwapRouter {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function getLpToken(ISwap _pool) internal view returns (address lpToken) {
        (,,,,,,, lpToken) = _pool.swapStorage();
    }

    function calculateConvert(ISwap fromPool, ISwap toPool, uint256 amount) external view returns (uint256){
        uint fromPoolLength = fromPool.getTokenLength();
        uint256[] memory amounts = fromPool.calculateRemoveLiquidity(address(this), amount);
        uint256[] memory meta_amounts = new uint256[](fromPoolLength);
        for (uint8 i = 0; i < fromPoolLength; i++) {
            IERC20 fromCoin = fromPool.getToken(i);
            uint toCoinIndex = toPool.getTokenIndex(address(fromCoin));
            meta_amounts[toCoinIndex] = amounts[i];
        }
        return toPool.calculateTokenAmount(address(this), meta_amounts, true);
    }

    function convert(ISwap fromPool, ISwap toPool, uint256 amount, uint256 minToMint, uint256 deadline) external returns (uint256) {
        uint fromPoolLength = fromPool.getTokenLength();
        uint toPoolLength = toPool.getTokenLength();
        require(address(fromPool) != address(toPool), "fromPool = toPool");
        require(fromPoolLength == toPoolLength, "Invalid token length");
        IERC20 fromToken = IERC20(getLpToken(fromPool));
        IERC20 toToken = IERC20(getLpToken(toPool));
        uint256[] memory min_amounts = new uint256[](fromPoolLength);
        // validate token length
        for (uint8 i = 0; i < fromPoolLength; i++) {
            IERC20 fromTokenCoin = fromPool.getToken(i);
            toPool.getTokenIndex(address(fromTokenCoin));
        }
        fromToken.transferFrom(msg.sender, address(this), amount);
        fromToken.approve(address(fromPool), amount);
        fromPool.removeLiquidity(amount, min_amounts, deadline);

        uint256[] memory meta_amounts = new uint256[](toPoolLength);
        for (uint8 i = 0; i < toPoolLength; i++) {
            IERC20 coin = toPool.getToken(i);
            uint256 addBalance = coin.balanceOf(address(this));
            coin.safeApprove(address(toPool), addBalance);
            meta_amounts[i] = addBalance;
        }
        toPool.addLiquidity(meta_amounts, minToMint, deadline);

        uint256 lpAmount = toToken.balanceOf(address(this));
        toToken.transfer(msg.sender, lpAmount);
        return lpAmount;
    }

    function addLiquidity(
        ISwap pool,
        ISwap basePool,
        uint256[] memory meta_amounts,
        uint256[] memory base_amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256) {
        IERC20 token = IERC20(getLpToken(pool));
        require(base_amounts.length == basePool.getTokenLength(), "Invalid base token length");
        require(meta_amounts.length == pool.getTokenLength(), "Invalid meta token length");
        bool deposit_base = false;
        for (uint8 i = 0; i < base_amounts.length; i++) {
            uint256 amount = base_amounts[i];
            if (amount > 0) {
                deposit_base = true;
                IERC20 coin = basePool.getToken(i);
                coin.safeTransferFrom(msg.sender, address(this), amount);
                uint256 transferred = coin.balanceOf(address(this));
                coin.safeApprove(address(basePool), transferred);
                base_amounts[i] = transferred;
            }
        }
        if (deposit_base) {
            basePool.addLiquidity(base_amounts, 0, deadline);
        }
        for (uint8 i = 0; i < meta_amounts.length; i++) {
            IERC20 coin = pool.getToken(i);
            if (meta_amounts[i] > 0) {
                coin.safeTransferFrom(msg.sender, address(this), meta_amounts[i]);
            }
            uint256 transferred = coin.balanceOf(address(this));
            coin.safeApprove(address(pool), transferred);
            meta_amounts[i] = transferred;
        }
        pool.addLiquidity(meta_amounts, minToMint, deadline);
        uint256 lpAmount = token.balanceOf(address(this));
        token.transfer(msg.sender, lpAmount);
        return lpAmount;
    }


    function removeLiquidity(
        ISwap pool,
        ISwap basePool,
        uint256 _amount,
        uint256[] calldata min_amounts_meta,
        uint256[] calldata min_amounts_base,
        uint256 deadline
    ) external returns (uint256[] memory amounts, uint256[] memory base_amounts) {
        IERC20 token = IERC20(getLpToken(pool));
        IERC20 baseToken = IERC20(getLpToken(basePool));
        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(address(pool), _amount);
        pool.removeLiquidity(_amount, min_amounts_meta, deadline);
        uint _base_amount = baseToken.balanceOf(address(this));
        baseToken.approve(address(basePool), _base_amount);

        basePool.removeLiquidity(_base_amount, min_amounts_base, deadline);
        // Transfer all coins out
        amounts = new uint256[](pool.getTokenLength());
        for (uint8 i = 0; i < pool.getTokenLength(); i++) {
            IERC20 coin = pool.getToken(i);
            amounts[i] = coin.balanceOf(address(this));
            if (amounts[i] > 0) {
                coin.safeTransfer(msg.sender, amounts[i]);
            }
        }
        base_amounts = new uint256[](basePool.getTokenLength());
        for (uint8 i = 0; i < basePool.getTokenLength(); i++) {
            IERC20 coin = basePool.getToken(i);
            base_amounts[i] = coin.balanceOf(address(this));
            if (base_amounts[i] > 0) {
                coin.safeTransfer(msg.sender, base_amounts[i]);
            }
        }
    }

    function removeBaseLiquidityOneToken(
        ISwap pool,
        ISwap basePool,
        uint256 _token_amount,
        uint8 i,
        uint256 _min_amount,
        uint256 deadline
    ) external returns (uint256) {
        IERC20 token = IERC20(getLpToken(pool));
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        token.transferFrom(msg.sender, address(this), _token_amount);
        token.approve(address(pool), _token_amount);
        pool.removeLiquidityOneToken(_token_amount, baseTokenIndex, 0, deadline);
        uint _base_amount = baseToken.balanceOf(address(this));
        baseToken.approve(address(basePool), _base_amount);
        basePool.removeLiquidityOneToken(_base_amount, i, _min_amount, deadline);
        IERC20 coin = basePool.getToken(i);
        uint coin_amount = coin.balanceOf(address(this));
        coin.safeTransfer(msg.sender, coin_amount);
        return coin_amount;
    }

    function calculateRemoveBaseLiquidityOneToken(
        ISwap pool,
        ISwap basePool,
        uint256 _token_amount,
        uint8 iBase
    ) external view returns (uint256 availableTokenAmount) {
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint _base_tokens = pool.calculateRemoveLiquidityOneToken(address(this), _token_amount, baseTokenIndex);
        availableTokenAmount = basePool.calculateRemoveLiquidityOneToken(address(this), _base_tokens, iBase);
    }

    function calculateTokenAmount(
        ISwap pool,
        ISwap basePool,
        uint256[] memory meta_amounts,
        uint256[] memory base_amounts,
        bool is_deposit
    ) external view returns (uint256) {
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256 _base_tokens = basePool.calculateTokenAmount(address(this), base_amounts, is_deposit);
        meta_amounts[baseTokenIndex] = meta_amounts[baseTokenIndex] + _base_tokens;
        return pool.calculateTokenAmount(address(this), meta_amounts, is_deposit);
    }

    function calculateRemoveLiquidity(
        ISwap pool,
        ISwap basePool,
        uint256 amount
    ) external view returns (
        uint256[] memory meta_amounts,
        uint256[] memory base_amounts
    ) {
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        meta_amounts = pool.calculateRemoveLiquidity(address(this), amount);
        uint256 lpAmount = meta_amounts[baseTokenIndex];
        meta_amounts[baseTokenIndex] = 0;
        base_amounts = basePool.calculateRemoveLiquidity(address(this), lpAmount);
    }

    function swapFromBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256)
    {
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256[] memory base_amounts = new uint256[](basePool.getTokenLength());
        base_amounts[tokenIndexFrom] = dx;
        IERC20 coin = basePool.getToken(tokenIndexFrom);
        coin.safeTransferFrom(msg.sender, address(this), dx);
        coin.safeIncreaseAllowance(address(basePool), dx);
        uint baseLpAmount = basePool.addLiquidity(base_amounts, 0, deadline);
        if (baseTokenIndex != tokenIndexTo) {
            baseToken.approve(address(pool), baseLpAmount);
            pool.swap(baseTokenIndex, tokenIndexTo, baseLpAmount, minDy, deadline);
        }
        IERC20 coinTo = pool.getToken(tokenIndexTo);
        uint amountOut = coinTo.balanceOf(address(this));
        coinTo.safeTransfer(msg.sender, amountOut);
        return amountOut;
    }

    function calculateSwapFromBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256) {
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256[] memory base_amounts = new uint256[](basePool.getTokenLength());
        base_amounts[tokenIndexFrom] = dx;
        uint baseLpAmount = basePool.calculateTokenAmount(address(this), base_amounts, true);
        if (baseTokenIndex == tokenIndexTo) {
            return baseLpAmount;
        }
        return pool.calculateSwap(baseTokenIndex, tokenIndexTo, baseLpAmount);
    }

    function swapToBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256)
    {
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        IERC20 coin = pool.getToken(tokenIndexFrom);
        coin.safeTransferFrom(msg.sender, address(this), dx);
        uint256 tokenLPAmount = dx;
        if (baseTokenIndex != tokenIndexFrom) {
            coin.safeIncreaseAllowance(address(pool), dx);
            tokenLPAmount = pool.swap(tokenIndexFrom, baseTokenIndex, dx, 0, deadline);
        }
        baseToken.approve(address(basePool), tokenLPAmount);
        basePool.removeLiquidityOneToken(tokenLPAmount, tokenIndexTo, minDy, deadline);
        IERC20 coinTo = basePool.getToken(tokenIndexTo);
        uint amountOut = coinTo.balanceOf(address(this));
        coinTo.safeTransfer(msg.sender, amountOut);
        return amountOut;

    }

    function calculateSwapToBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256) {
        IERC20 baseToken = IERC20(getLpToken(basePool));
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256 tokenLPAmount = dx;
        if (baseTokenIndex != tokenIndexFrom) {
            tokenLPAmount = pool.calculateSwap(tokenIndexFrom, baseTokenIndex, dx);
        }
        return basePool.calculateRemoveLiquidityOneToken(address(this), tokenLPAmount, tokenIndexTo);
    }
}