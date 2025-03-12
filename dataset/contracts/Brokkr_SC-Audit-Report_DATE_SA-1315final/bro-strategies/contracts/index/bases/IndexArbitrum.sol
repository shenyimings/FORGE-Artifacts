// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IndexStrategyUpgradeable } from "../bases/IndexStrategyUpgradeable.sol";
import { IChainlinkAggregatorV3 } from "../dependencies/IChainlinkAggregatorV3.sol";
import { Constants } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";

/**
 * @dev Contract IndexArbitrum is an extension of IndexStrategyUpgradeable.
 */
contract IndexArbitrum is IndexStrategyUpgradeable {
    /**
     * @dev Adds a swap route.
     * @param token The token address.
     * @param router The router address.
     * @param dex The DEX.
     * @param pair The pair address.
     */
    function addSwapRoute(
        address token,
        address router,
        SwapAdapter.DEX dex,
        address pair
    ) external onlyOwner {
        SwapAdapter.PairData memory pairData = SwapAdapter.PairData(
            pair,
            abi.encode(0)
        );

        addSwapRoute(token, router, dex, pairData);
    }

    /**
     * @dev Adds a swap route with a bin step.
     * @param token The token address.
     * @param router The router address.
     * @param dex The DEX.
     * @param pair The pair address.
     * @param binStep The bin step as a uint256.
     */
    function addSwapRoute(
        address token,
        address router,
        SwapAdapter.DEX dex,
        address pair,
        uint256 binStep
    ) external onlyOwner {
        SwapAdapter.PairData memory pairData = SwapAdapter.PairData(
            pair,
            abi.encode(binStep)
        );

        addSwapRoute(token, router, dex, pairData);
    }

    /**
     * @dev Adds a swap route with a factory.
     * @param token The token address.
     * @param router The router address.
     * @param dex The DEX.
     * @param pair The pair address.
     * @param factory The factory address.
     */
    function addSwapRoute(
        address token,
        address router,
        SwapAdapter.DEX dex,
        address pair,
        address factory
    ) external onlyOwner {
        SwapAdapter.PairData memory pairData = SwapAdapter.PairData(
            pair,
            abi.encode(factory)
        );

        addSwapRoute(token, router, dex, pairData);
    }
}
