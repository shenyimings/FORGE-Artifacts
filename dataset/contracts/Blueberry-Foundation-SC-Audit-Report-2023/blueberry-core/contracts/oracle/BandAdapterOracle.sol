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

import "./BaseAdapter.sol";
import "../interfaces/IBaseOracle.sol";
import "../interfaces/band/IStdReference.sol";

/**
 * @author BlueberryProtocol
 * @title BandAdapterOracle
 * @notice Oracle Adapter contract which provides price feeds from Band Protocol
 */
contract BandAdapterOracle is IBaseOracle, BaseAdapter {
    /// @dev BandStandardRef oracle contract
    IStdReference public ref;

    /// @dev Mapping from token to symbol string (Band provides price feeds by token symbols)
    mapping(address => string) public symbols;

    event SetRef(address ref);
    event SetSymbol(address token, string symbol);

    constructor(IStdReference ref_) {
        if (address(ref_) == address(0)) revert Errors.ZERO_ADDRESS();

        ref = ref_;
    }

    /// @notice Set standard reference source
    /// @param ref_ Standard reference source
    function setRef(IStdReference ref_) external onlyOwner {
        if (address(ref_) == address(0)) revert Errors.ZERO_ADDRESS();
        ref = ref_;
        emit SetRef(address(ref_));
    }

    /// @notice Set token symbols
    /// @param tokens List of tokens
    /// @param syms List of string symbols
    function setSymbols(
        address[] calldata tokens,
        string[] calldata syms
    ) external onlyOwner {
        if (syms.length != tokens.length) revert Errors.INPUT_ARRAY_MISMATCH();
        for (uint256 idx = 0; idx < syms.length; idx++) {
            if (tokens[idx] == address(0)) revert Errors.ZERO_ADDRESS();

            symbols[tokens[idx]] = syms[idx];
            emit SetSymbol(tokens[idx], syms[idx]);
        }
    }

    /// @notice Return the USD price of given token, multiplied by 10**18.
    /// @dev Band protocol is already providing 1e18 precision feeds
    /// @param token The ERC-20 token to get the price of.
    function getPrice(address token) external view override returns (uint256) {
        string memory sym = symbols[token];
        uint256 maxDelayTime = timeGaps[token];
        if (bytes(sym).length == 0) revert Errors.NO_SYM_MAPPING(token);
        if (maxDelayTime == 0) revert Errors.NO_MAX_DELAY(token);

        IStdReference.ReferenceData memory data = ref.getReferenceData(
            sym,
            "USD"
        );
        if (
            data.lastUpdatedBase < block.timestamp - maxDelayTime ||
            data.lastUpdatedQuote < block.timestamp - maxDelayTime
        ) revert Errors.PRICE_OUTDATED(token);

        return data.rate;
    }
}
