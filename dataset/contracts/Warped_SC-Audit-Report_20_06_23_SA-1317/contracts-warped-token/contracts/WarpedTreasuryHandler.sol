// SPDX-License-Identifier: MIT

/**
 __      __  _____ _______________________________________   
/  \    /  \/  _  \\______   \______   \_   _____/\______ \  
\   \/\/   /  /_\  \|       _/|     ___/|    __)_  |    |  \ 
 \        /    |    \    |   \|    |    |        \ |    `   \
  \__/\  /\____|__  /____|_  /|____|   /_______  //_______  /
       \/         \/       \/                  \/         \/ 
 */

pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {ITreasuryHandler} from "./interfaces/ITreasuryHandler.sol";

/**
 * @title Treasury handler contract
 * @dev Sells tokens that have accumulated through taxes and sends the resulting ETH to the treasury. If
 * `liquidityBasisPoints` has been set to a non-zero value, then that percentage will instead be added to the designated
 * liquidity pool.
 */
contract WarpedTreasuryHandler is ITreasuryHandler, Ownable {
    using Address for address payable;
    using SafeERC20 for IERC20;

    IPoolManager public poolManager;

    /// @notice The Treasury address.
    address payable public treasury;

    /// @notice The token that accumulates through taxes. This will be sold for ETH.
    IERC20 public token;

    /// @notice The basis points of tokens to sell and add as liquidity to the pool.
    uint256 public liquidityBasisPoints;

    /// @notice The maximum price impact the sell (initiated from this contract) may have.
    uint256 public priceImpactBasisPoints;

    /// @dev swap contract balance if it's over this value
    uint256 private _taxSwap;

    bool private _isInitialized;

    /// @notice The Uniswap router that handles the sell and liquidity operations.
    IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    /// @notice Emitted when the basis points value of tokens to add as liquidity is updated.
    event LiquidityBasisPointsUpdated(uint256 oldBasisPoints, uint256 newBasisPoints);

    /// @notice Emitted when the maximum price impact basis points value is updated.
    event PriceImpactBasisPointsUpdated(uint256 oldBasisPoints, uint256 newBasisPoints);

    /// @notice Emitted when the treasury address is updated.
    event TreasuryAddressUpdated(address oldTreasuryAddress, address newTreasuryAddress);

    /// @notice Emitted when _taxSwap is updated.
    event TaxSwapUpdated(uint256 newValue);

    /// @notice Emitted when liquidity added successfully
    event LiquidityAdded(uint amountToken, uint amountETH, uint liquidity);

    /// @notice Constructor of tax handler contract
    /// @param _poolManager exchange pool manager address
    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    /**
     * @notice Allow contract to accept ETH.
     */
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    /**
     * @param treasuryAddress Address of treasury to use.
     * @param tokenAddress Address of token to accumulate and sell.
     */
    function initialize(address treasuryAddress, address tokenAddress) external onlyOwner {
        require(!_isInitialized, "Already initialized");
        require(treasuryAddress != address(0), "treasury is zero address");
        require(tokenAddress != address(0), "token address is zero address");

        treasury = payable(treasuryAddress);
        token = IERC20(tokenAddress);
        liquidityBasisPoints = 0;
        priceImpactBasisPoints = 500;
        _taxSwap = 10_000_000 * 10 ** 18;
        _isInitialized = true;
    }

    /**
     * @notice Perform operations before a sell action (or a liquidity addition) is executed. The accumulated tokens are
     * then sold for ETH. In case the number of accumulated tokens exceeds the price impact percentage threshold, then
     * the number will be adjusted to stay within the threshold. If a non-zero percentage is set for liquidity, then
     * that percentage will be added to the primary liquidity pool instead of being sold for ETH and sent to the
     * treasury.
     * @param benefactor Address of the benefactor.
     * @param beneficiary Address of the beneficiary.
     * @param amount Number of tokens in the transfer.
     */
    function processTreasury(address benefactor, address beneficiary, uint256 amount) external override {
        if (!_isInitialized || benefactor == address(0x0)) {
            // skip when not initialized or mint
            return;
        }

        // No actions are done on transfers other than sells.
        if (!poolManager.isPoolAddress(beneficiary)) {
            return;
        }

        uint256 contractTokenBalance = token.balanceOf(address(this));
        if (contractTokenBalance > _taxSwap) {
            uint256 primaryPoolBalance = token.balanceOf(poolManager.primaryPool());
            uint256 maxPriceImpactSale = (primaryPoolBalance * priceImpactBasisPoints) / 10000;

            contractTokenBalance = _taxSwap > amount ? amount : _taxSwap;

            // Ensure the price impact is within reasonable bounds.
            if (contractTokenBalance > maxPriceImpactSale) {
                contractTokenBalance = maxPriceImpactSale;
            }

            // The number of tokens to sell for liquidity purposes. This is calculated as follows:
            //
            //      B     P
            //  L = - * -----
            //      2   10000
            //
            // Where:
            //  L = tokens to sell for liquidity
            //  B = available token balance
            //  P = basis points of tokens to use for liquidity
            //
            // The number is divided by two to preserve the token side of the token/WETH pool.
            uint256 tokensForLiquidity = (contractTokenBalance * liquidityBasisPoints) / 20000;
            uint256 tokensForSwap = contractTokenBalance - tokensForLiquidity;

            uint256 currentWeiBalance = address(this).balance;
            _swapTokensForEth(tokensForSwap);
            uint256 weiEarned = address(this).balance - currentWeiBalance;

            // No need to divide this number, because that was only to have enough tokens remaining to pair with this
            // ETH value.
            uint256 weiForLiquidity = (weiEarned * liquidityBasisPoints) / 10000;

            if (tokensForLiquidity > 0) {
                _addLiquidity(tokensForLiquidity, weiForLiquidity);
            }

            // It's cheaper to get the active balance rather than calculating based off of the `currentWeiBalance` and
            // `weiForLiquidity` numbers.
            uint256 remainingWeiBalance = address(this).balance;
            if (remainingWeiBalance > 0) {
                treasury.sendValue(remainingWeiBalance);
            }
        }
    }

    /**
     * @notice Set new liquidity basis points value.
     * @param newBasisPoints New liquidity basis points value. Cannot exceed 10,000 (i.e., 100%) as that would break the
     * calculation.
     */
    function setLiquidityBasisPoints(uint256 newBasisPoints) external onlyOwner {
        require(newBasisPoints <= 10000, "Max is 10000");

        uint256 oldBasisPoints = liquidityBasisPoints;
        liquidityBasisPoints = newBasisPoints;

        emit LiquidityBasisPointsUpdated(oldBasisPoints, newBasisPoints);
    }

    /**
     * @notice Set new price impact basis points value.
     * @param newBasisPoints New price impact basis points value.
     */
    function setPriceImpactBasisPoints(uint256 newBasisPoints) external onlyOwner {
        require(newBasisPoints < 1500, "Too high value");

        uint256 oldBasisPoints = priceImpactBasisPoints;
        priceImpactBasisPoints = newBasisPoints;

        emit PriceImpactBasisPointsUpdated(oldBasisPoints, newBasisPoints);
    }

    /**
     * @notice Set new treasury address.
     * @param newTreasuryAddress New treasury address.
     */
    function setTreasury(address newTreasuryAddress) external onlyOwner {
        require(newTreasuryAddress != address(0), "Zero address");

        address oldTreasuryAddress = address(treasury);
        treasury = payable(newTreasuryAddress);

        emit TreasuryAddressUpdated(oldTreasuryAddress, newTreasuryAddress);
    }

    /**
     * @notice Withdraw any tokens or ETH stuck in the treasury handler.
     * @param tokenAddress Address of the token to withdraw. If set to the zero address, ETH will be withdrawn.
     * @param amount The number of tokens to withdraw.
     */
    function withdraw(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(0)) {
            treasury.sendValue(amount);
        } else {
            IERC20(tokenAddress).safeTransfer(address(treasury), amount);
        }
    }

    function updateTaxSwap(uint256 taxSwap) external onlyOwner {
        require(taxSwap > 0, "Zero taxSwap");
        _taxSwap = taxSwap;
        emit TaxSwapUpdated(taxSwap);
    }

    /**
     * @dev Swap accumulated tokens for ETH.
     * @param tokenAmount Number of tokens to swap for ETH.
     */
    function _swapTokensForEth(uint256 tokenAmount) internal {
        // The ETH/token pool is the primary pool. It always exists.
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = UNISWAP_V2_ROUTER.WETH();

        // Call the getAmountsOut function to estimate the output amounts
        uint256[] memory amountsOut = UNISWAP_V2_ROUTER.getAmountsOut(tokenAmount, path);
        // Set the minimum amounts slightly below the estimated output amounts
        uint256 amountETHMin = amountsOut[1] - (amountsOut[1] / 100); // consider about 1 percent slippage

        // Ensure the router can perform the swap for the designated number of tokens.
        token.safeApprove(address(UNISWAP_V2_ROUTER), tokenAmount);
        UNISWAP_V2_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            amountETHMin,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Add liquidity to primary pool.
     * @param tokenAmount Number of tokens to add as liquidity.
     * @param weiAmount ETH value to pair with the tokens.
     */
    function _addLiquidity(uint256 tokenAmount, uint256 weiAmount) internal {
        // Ensure the router can perform the transfer for the designated number of tokens.
        token.safeApprove(address(UNISWAP_V2_ROUTER), tokenAmount);

        // Create a dynamic array containing the token and ETH addresses in the desired order
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = UNISWAP_V2_ROUTER.WETH();

        // Call the getAmountsOut function to estimate the output amounts
        uint256[] memory amountsOut = UNISWAP_V2_ROUTER.getAmountsOut(tokenAmount, path);

        // Set the minimum amounts slightly below the estimated output amounts
        uint256 amountTokenMin = amountsOut[0] - (amountsOut[0] / 100); // consider about 1 percent slippage
        uint256 amountETHMin = amountsOut[1] - (amountsOut[1] / 100); // consider about 1 percent slippage

        // Both minimum values are set to zero to allow for any form of slippage.
        (uint amountToken, uint amountETH, uint liquidity) = UNISWAP_V2_ROUTER.addLiquidityETH{value: weiAmount}(
            address(token),
            tokenAmount,
            amountTokenMin,
            amountETHMin,
            address(treasury),
            block.timestamp
        );
        emit LiquidityAdded(amountToken, amountETH, liquidity);
    }
}
