// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "./BaseAdapter.sol";
import "../interfaces/IBaseOracle.sol";
import "../interfaces/chainlink/IFeedRegistry.sol";

/**
 * @author BlueberryProtocol
 * @title ChainlinkAdapterOracle
 * @notice Oracle Adapter contract which provides price feeds from Chainlink
 */
contract ChainlinkAdapterOracle is IBaseOracle, BaseAdapter {
    using SafeCast for int256;

    // Chainlink denominations
    // (source: https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/Denominations.sol)
    IFeedRegistry public registry;
    address public constant USD = address(840);

    /// @dev Mapping from original token to remapped token for price querying (e.g. WBTC -> BTC, WETH -> ETH)
    mapping(address => address) public remappedTokens;

    event SetRegistry(address registry);
    event SetTokenRemapping(
        address indexed token,
        address indexed remappedToken
    );

    constructor(IFeedRegistry registry_) {
        if (address(registry_) == address(0)) revert Errors.ZERO_ADDRESS();

        registry = registry_;
    }

    /// @notice Set chainlink feed registry source
    /// @param registry_ Chainlink feed registry source
    function setFeedRegistry(IFeedRegistry registry_) external onlyOwner {
        if (address(registry_) == address(0)) revert Errors.ZERO_ADDRESS();
        registry = registry_;
        emit SetRegistry(address(registry_));
    }

    /// @notice Set token remapping
    /// @param tokens_ List of tokens to set remapping
    /// @param remappedTokens_ List of tokens to set remapping to
    function setTokenRemappings(
        address[] calldata tokens_,
        address[] calldata remappedTokens_
    ) external onlyOwner {
        if (remappedTokens_.length != tokens_.length)
            revert Errors.INPUT_ARRAY_MISMATCH();
        for (uint256 idx = 0; idx < tokens_.length; idx++) {
            if (tokens_[idx] == address(0)) revert Errors.ZERO_ADDRESS();

            remappedTokens[tokens_[idx]] = remappedTokens_[idx];
            emit SetTokenRemapping(tokens_[idx], remappedTokens_[idx]);
        }
    }

    /**
     * @notice Returns the USD price of given token, price value has 18 decimals
     * @param token_ Token address to get price of
     * @return price USD price of token in 18 decimal
     */
    function getPrice(address token_) external view override returns (uint256) {
        // remap token if possible
        address token = remappedTokens[token_];
        if (token == address(0)) token = token_;

        uint256 maxDelayTime = timeGaps[token];
        if (maxDelayTime == 0) revert Errors.NO_MAX_DELAY(token_);

        // Get token-USD price
        uint256 decimals = registry.decimals(token, USD);
        (, int256 answer, , uint256 updatedAt, ) = registry.latestRoundData(
            token,
            USD
        );
        if (updatedAt < block.timestamp - maxDelayTime)
            revert Errors.PRICE_OUTDATED(token_);
        if (answer <= 0) revert Errors.PRICE_NEGATIVE(token_);

        return
            (answer.toUint256() * Constants.PRICE_PRECISION) / 10 ** decimals;
    }
}
