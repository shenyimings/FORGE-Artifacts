// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IChainlinkAggregatorV3 } from "../dependencies/IChainlinkAggregatorV3.sol";
import { IIndexToken } from "../interfaces/IIndexToken.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";

interface IIndexStrategy {
    event Mint(
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 amountToken,
        uint256 amountIndex,
        uint64 affiliateId
    );

    event Burn(
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 amountToken,
        uint256 amountIndex
    );

    function mintIndexFromToken(
        address token,
        uint256 amountTokenMax,
        uint256 amountIndexMin,
        address recipient,
        uint64 affiliateId
    ) external returns (uint256 amountIndex, uint256 amountToken);

    function burnExactIndexForToken(
        address token,
        uint256 amountTokenMin,
        uint256 amountIndex,
        address recipient
    ) external returns (uint256 amountToken);

    function getAmountIndexFromToken(address token, uint256 amountTokenMax)
        external
        returns (uint256 amountIndex, uint256 amountToken);

    function getAmountTokenFromExactIndex(address token, uint256 amountIndex)
        external
        returns (uint256 amountToken);

    function setOracle(address oracle) external;

    function addSwapRoute(
        address token,
        address router,
        SwapAdapter.DEX dex,
        SwapAdapter.PairData memory pairData
    ) external;

    function addWhitelistedTokens(address[] memory tokens) external;

    function removeSwapRoute(address token, address router) external;

    function removeWhitelistedTokens(address[] memory tokens) external;

    function allComponents() external view returns (address[] memory);

    function allWhitelistedTokens() external view returns (address[] memory);

    function equityValuation(bool maximize, bool includeAmmPrice)
        external
        view
        returns (uint256);

    function indexToken() external view returns (IIndexToken);
}
