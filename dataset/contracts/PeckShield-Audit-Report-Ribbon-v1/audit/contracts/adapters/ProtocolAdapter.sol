// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;
pragma experimental ABIEncoderV2;

import {IProtocolAdapter, ProtocolAdapterTypes} from "./IProtocolAdapter.sol";

/**
 * @notice ProtocolAdapter is used to shadow IProtocolAdapter to provide functions that delegatecall's the underlying IProtocolAdapter functions.
 */
library ProtocolAdapter {
    function delegateOptionsExist(
        IProtocolAdapter adapter,
        ProtocolAdapterTypes.OptionTerms calldata optionTerms
    ) external view returns (bool) {
        (bool success, bytes memory result) =
            address(adapter).staticcall(
                abi.encodeWithSignature(
                    "optionsExist((address,address,address,uint256,uint256,uint8,address))",
                    optionTerms
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (bool));
    }

    function delegateGetOptionsAddress(
        IProtocolAdapter adapter,
        ProtocolAdapterTypes.OptionTerms calldata optionTerms
    ) external view returns (address) {
        (bool success, bytes memory result) =
            address(adapter).staticcall(
                abi.encodeWithSignature(
                    "getOptionsAddress((address,address,address,uint256,uint256,uint8,address))",
                    optionTerms
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (address));
    }

    function delegatePremium(
        IProtocolAdapter adapter,
        ProtocolAdapterTypes.OptionTerms calldata optionTerms,
        uint256 purchaseAmount
    ) external view returns (uint256) {
        (bool success, bytes memory result) =
            address(adapter).staticcall(
                abi.encodeWithSignature(
                    "premium((address,address,address,uint256,uint256,uint8,address),uint256)",
                    optionTerms,
                    purchaseAmount
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (uint256));
    }

    function delegateExerciseProfit(
        IProtocolAdapter adapter,
        address options,
        uint256 optionID,
        uint256 amount
    ) external view returns (uint256) {
        (bool success, bytes memory result) =
            address(adapter).staticcall(
                abi.encodeWithSignature(
                    "exerciseProfit(address,uint256,uint256)",
                    options,
                    optionID,
                    amount
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (uint256));
    }

    function delegatePurchase(
        IProtocolAdapter adapter,
        ProtocolAdapterTypes.OptionTerms calldata optionTerms,
        uint256 purchaseAmount,
        uint256 maxCost
    ) external returns (uint256) {
        (bool success, bytes memory result) =
            address(adapter).delegatecall(
                abi.encodeWithSignature(
                    "purchase((address,address,address,uint256,uint256,uint8,address),uint256,uint256)",
                    optionTerms,
                    purchaseAmount,
                    maxCost
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (uint256));
    }

    function delegatePurchaseWithZeroEx(
        IProtocolAdapter adapter,
        ProtocolAdapterTypes.OptionTerms calldata optionTerms,
        ProtocolAdapterTypes.ZeroExOrder calldata zeroExOrder
    ) external {
        (bool success, bytes memory result) =
            address(adapter).delegatecall(
                abi.encodeWithSignature(
                    "purchaseWithZeroEx((address,address,address,uint256,uint256,uint8,address),(address,address,address,address,uint256,uint256,uint256,bytes))",
                    optionTerms,
                    zeroExOrder
                )
            );
        revertWhenFail(success, result);
    }

    function delegateExercise(
        IProtocolAdapter adapter,
        address options,
        uint256 optionID,
        uint256 amount,
        address recipient
    ) external {
        (bool success, bytes memory result) =
            address(adapter).delegatecall(
                abi.encodeWithSignature(
                    "exercise(address,uint256,uint256,address)",
                    options,
                    optionID,
                    amount,
                    recipient
                )
            );
        revertWhenFail(success, result);
    }

    function delegateClaimRewards(
        IProtocolAdapter adapter,
        address rewardsAddress,
        uint256[] calldata optionIDs
    ) external returns (uint256) {
        (bool success, bytes memory result) =
            address(adapter).delegatecall(
                abi.encodeWithSignature(
                    "claimRewards(address,uint256[])",
                    rewardsAddress,
                    optionIDs
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (uint256));
    }

    function delegateRewardsClaimable(
        IProtocolAdapter adapter,
        address rewardsAddress,
        uint256[] calldata optionIDs
    ) external view returns (uint256) {
        (bool success, bytes memory result) =
            address(adapter).staticcall(
                abi.encodeWithSignature(
                    "rewardsClaimable(address,uint256[])",
                    rewardsAddress,
                    optionIDs
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (uint256));
    }

    function delegateCreateShort(
        IProtocolAdapter adapter,
        ProtocolAdapterTypes.OptionTerms calldata optionTerms,
        uint256 amount
    ) external returns (uint256) {
        (bool success, bytes memory result) =
            address(adapter).delegatecall(
                abi.encodeWithSignature(
                    "createShort((address,address,address,uint256,uint256,uint8,address),uint256)",
                    optionTerms,
                    amount
                )
            );
        revertWhenFail(success, result);
        return abi.decode(result, (uint256));
    }

    function delegateCloseShort(IProtocolAdapter adapter)
        external
        returns (uint256)
    {
        (bool success, bytes memory result) =
            address(adapter).delegatecall(
                abi.encodeWithSignature("closeShort()")
            );
        require(success, getRevertMsg(result));
        return abi.decode(result, (uint256));
    }

    function revertWhenFail(bool success, bytes memory returnData)
        private
        pure
    {
        if (success) return;
        revert(getRevertMsg(returnData));
    }

    function getRevertMsg(bytes memory _returnData)
        private
        pure
        returns (string memory)
    {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "ProtocolAdapter: reverted";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
