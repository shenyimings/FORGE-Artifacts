// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { AppStorage, LibAppStorage } from "../AppStorage.sol";
import { Modifiers } from "../Modifiers.sol";
import { LibObject } from "../libs/LibObject.sol";
import { LibAdmin } from "../libs/LibAdmin.sol";
import { LibFeeRouter } from "../libs/LibFeeRouter.sol";
import { PolicyCommissionsBasisPoints, TradingCommissionsBasisPoints } from "../interfaces/FreeStructs.sol";

/**
 * @title Administration
 * @notice Exposes methods that require administrative priviledges
 * @dev Use it to configure various core parameters
 */
contract AdminFacet is Modifiers {
    /**
     * @notice Set the equilibrium level to `_newLevel` in the NDF
     * @dev Desired amount of NAYM tokens in NDF
     * @param _newLevel new value for the equilibrium level
     */
    function setEquilibriumLevel(uint256 _newLevel) external assertSysAdmin {
        LibAdmin._setEquilibriumLevel(_newLevel);
    }

    /**
     * @notice Set the maximum discount `_newDiscount` in the NDF
     * @param _newDiscount new value for the max discount
     */
    function setMaxDiscount(uint256 _newDiscount) external assertSysAdmin {
        LibAdmin._setMaxDiscount(_newDiscount);
    }

    /**
     * @notice Set the targeted NAYM allocation to `_newTarget` in the NDF
     * @param _newTarget new value for the target allocation
     */
    function setTargetNaymsAllocation(uint256 _newTarget) external assertSysAdmin {
        LibAdmin._setTargetNaymsAllocation(_newTarget);
    }

    /**
     * @notice Set the `_newToken` as a token for dicounts
     * @param _newToken token to be used for discounts
     */
    function setDiscountToken(address _newToken) external assertSysAdmin {
        LibAdmin._setDiscountToken(_newToken);
    }

    /**
     * @notice Set `_newFee` as NDF pool fee
     * @param _newFee new value to be used as transaction fee in the NDF pool
     */
    function setPoolFee(uint24 _newFee) external assertSysAdmin {
        LibAdmin._setPoolFee(_newFee);
    }

    /**
     * @notice Set `_newCoefficient` as the coefficient
     * @param _newCoefficient new value to be used as coefficient
     */
    function setCoefficient(uint256 _newCoefficient) external assertSysAdmin {
        LibAdmin._setCoefficient(_newCoefficient);
    }

    /**
     * @notice Set `_newMax` as the max dividend denominations value.
     * @param _newMax new value to be used.
     */
    function setMaxDividendDenominations(uint8 _newMax) external assertSysAdmin {
        LibAdmin._updateMaxDividendDenominations(_newMax);
    }

    /**
     * @notice Update policy commission basis points configuration.
     * @param _policyCommissions policy commissions configuration to set
     */
    function setPolicyCommissionsBasisPoints(PolicyCommissionsBasisPoints calldata _policyCommissions) external assertSysAdmin {
        LibFeeRouter._updatePolicyCommissionsBasisPoints(_policyCommissions);
    }

    /**
     * @notice Update trading commission basis points configuration.
     * @param _tradingCommissions trading commissions configuration to set
     */
    function setTradingCommissionsBasisPoints(TradingCommissionsBasisPoints calldata _tradingCommissions) external assertSysAdmin {
        LibFeeRouter._updateTradingCommissionsBasisPoints(_tradingCommissions);
    }

    /**
     * @notice Get the discount token
     * @return address of the token used for discounts
     */
    function getDiscountToken() external view returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.discountToken;
    }

    /**
     * @notice Get the equilibrium level
     * @return equilibrium level value
     */
    function getEquilibriumLevel() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.equilibriumLevel;
    }

    /**
     * @notice Get current NAYM allocation
     * @return total number of NAYM tokens
     */
    function getActualNaymsAllocation() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.actualNaymsAllocation;
    }

    /**
     * @notice Get the target NAYM allocation
     * @return desired supply of NAYM tokens
     */
    function getTargetNaymsAllocation() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.targetNaymsAllocation;
    }

    /**
     * @notice Get the maximum discount
     * @return max discount value
     */
    function getMaxDiscount() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.maxDiscount;
    }

    /**
     * @notice Get the pool fee
     * @return current pool fee
     */
    function getPoolFee() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.poolFee;
    }

    /**
     * @notice Get the rewards coeficient
     * @return coefficient for rewards
     */
    function getRewardsCoefficient() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.rewardsCoefficient;
    }

    /**
     * @notice Get the max dividend denominations value
     * @return max dividend denominations
     */
    function getMaxDividendDenominations() external view returns (uint8) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.maxDividendDenominations;
    }

    /**
     * @notice is the specified token an external ERC20?
     * @param _tokenId token address converted to bytes32
     * @return whether token issupported or not
     */
    function isSupportedExternalToken(bytes32 _tokenId) external view returns (bool) {
        return LibAdmin._isSupportedExternalToken(_tokenId);
    }

    /**
     * @notice Add another token to the supported tokens list
     * @param _tokenAddress address of the token to support
     */
    function addSupportedExternalToken(address _tokenAddress) external assertSysAdmin {
        LibAdmin._addSupportedExternalToken(_tokenAddress);
    }

    /**
     * @notice Get the supported tokens list as an array
     * @return array containing address of all supported tokens
     */
    function getSupportedExternalTokens() external view returns (address[] memory) {
        return LibAdmin._getSupportedExternalTokens();
    }

    /**
     * @notice Gets the System context ID.
     * @return System Identifier
     */
    function getSystemId() external pure returns (bytes32) {
        return LibAdmin._getSystemId();
    }
}
