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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {WarpedToken} from "./WarpedToken.sol";
import {WarpedTaxHandler} from "./WarpedTaxHandler.sol";
import {WarpedTreasuryHandler, IUniswapV2Router02} from "./WarpedTreasuryHandler.sol";
import {WarpedPoolManager, EnumerableSet, IPoolManager} from "./WarpedPoolManager.sol";

import {IUniswapV2Factory} from "./interfaces/IUniswapV2Router02.sol";

/**
 * @title WARPED token manager.
 * @dev Manage WARPED token such as creating token and adding liquidity.
 */
contract WarpedTokenManager is WarpedPoolManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @notice Emitted when liquidity added successfully
    event LiquidityAdded(uint amountToken, uint amountETH, uint liquidity);

    /// @notice WARPED token
    IERC20 public warpedToken;
    /// @notice Uniswap v2 router address
    IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    /// @notice Constructor of WARPED token manager
    /// @dev Create TaxHandler, TreasuryHandler, and Token contract
    /// @param treasuryAddress final tax treasury address
    /// @param nftContracts array of addresses of NFT contracts to calculate tax rate
    /// @param nftLevels array of levels of NFT contracts to calculate tax rate
    constructor(address treasuryAddress, address[] memory nftContracts, uint8[] memory nftLevels) {
        require(treasuryAddress != address(0), "treasury is zero address");

        // 1. Create treasury and tax Handler
        WarpedTreasuryHandler treasuryHandler = new WarpedTreasuryHandler(IPoolManager(this));
        WarpedTaxHandler taxHandler = new WarpedTaxHandler(IPoolManager(this), nftContracts, nftLevels);

        // 2. Create token contract and initilize treasury handler
        WarpedToken tokenContract = new WarpedToken(_msgSender(), address(taxHandler), address(treasuryHandler));
        // Initialize treasury handler with created token contract
        treasuryHandler.initialize(treasuryAddress, address(tokenContract));

        // 3. Transfer ownership of tax and transfer handlers into msgSender
        taxHandler.transferOwnership(_msgSender());
        treasuryHandler.transferOwnership(_msgSender());

        // 4. Transfer ownership of token contract into msgSender
        tokenContract.transferOwnership(_msgSender());
        warpedToken = IERC20(tokenContract);
    }

    /// @notice Ownable function to create and add liquidity
    /// @param amountToLiquidity amount of new tokens to add into liquidity
    function addLiquidity(uint256 amountToLiquidity) external payable onlyOwner {
        // 1. Receive token from deployer wallet
        warpedToken.safeTransferFrom(_msgSender(), address(this), amountToLiquidity);

        // 2. Approve token to use by uniswap router
        warpedToken.safeApprove(address(UNISWAP_V2_ROUTER), amountToLiquidity);

        // 3. Create uniswap pair
        address uniswapV2Pair = IUniswapV2Factory(UNISWAP_V2_ROUTER.factory()).createPair(
            address(warpedToken),
            UNISWAP_V2_ROUTER.WETH()
        );

        // 4. Add liquidity
        (uint amountToken, uint amountETH, uint liquidity) = UNISWAP_V2_ROUTER.addLiquidityETH{
            value: address(this).balance
        }(address(warpedToken), amountToLiquidity, amountToLiquidity, msg.value, owner(), block.timestamp);
        emit LiquidityAdded(amountToken, amountETH, liquidity);

        // 5. Add exchange pool and set primary pool
        _exchangePools.add(address(uniswapV2Pair));
        primaryPool = address(uniswapV2Pair);
    }
}
