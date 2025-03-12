// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../shared/BaseStorage.sol";

// libraries
import "../libraries/Max/128Bit.sol";
import "../libraries/Math.sol";

// other imports
import "../interfaces/IBaseStrategy.sol";
import "../interfaces/IStrategyRegistry.sol";

/**
 * @notice Spool part of implementation dealing with strategy related processing
 */
abstract contract SpoolStrategyHelper is BaseStorage {
    
    IStrategyRegistry private immutable strategyRegistry;

    constructor (IStrategyRegistry _strategyRegistry) {
        strategyRegistry = _strategyRegistry;
    }

    /**
     * @notice Yields the total underlying funds of a strategy.
     *
     * @dev
     * The function is not set as view given that it performs a delegate call
     * instruction to the strategy.
     * @param strategy Strategy address
     * @return Total underlying funds
     */
    function _totalUnderlying(address strategy)
        internal
        returns (uint128)
    {
        bytes memory data = _relay(
            strategy,
            abi.encodeWithSelector(IBaseStrategy.getStrategyBalance.selector)
        );

        return abi.decode(data, (uint128));
    }

    /**
     * @notice Get strategy total underlying balance including rewards
     * @param strategy Strategy address
     * @return strategyBaƒçance Returns strategy balance with the rewards
     */
    function _getStratValue(
        address strategy
    ) internal returns(uint128) {
        bytes memory data = _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.getStrategyUnderlyingWithRewards.selector
            )
        );

        return abi.decode(data, (uint128));
    }

    /**
     * @notice Invoke claim rewards for a strategy
     * @param strategy Strategy address
     * @param swapData Swap slippage and path
     */
    function _claimRewards(
        address strategy,
        SwapData[] memory swapData
    ) internal {
        _relay(
            strategy,
            abi.encodeWithSelector(
                IBaseStrategy.claimRewards.selector,
                swapData
            )
        );
    }

    /**
     * @notice Relays the particular action to the strategy via delegatecall.
     * @param strategy Strategy address to delegate the call to
     * @param payload Data to pass when delegating call
     * @return Response received when delegating call
     */
    function _relay(address strategy, bytes memory payload)
        internal
        returns (bytes memory)
    {
        address stratImpl = strategyRegistry.getImplementation(address(strategy));
        (bool success, bytes memory data) = stratImpl.delegatecall(payload);
        if (!success) revert(_getRevertMsg(data));
        return data;
    }

    /**
     * @notice Decode revert message
     * @param _returnData Data returned by delegatecall
     * @return Revert string
     */
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // if the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "SILENT";
        assembly {
        // slice the sig hash
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // all that remains is the revert string
    }
}
