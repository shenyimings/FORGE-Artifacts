// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Aspida's CoreTreasury module
 * @dev This contract is an abstract contract that defines the core treasury functionality of Aspida.
 * @dev It contains internal functions to set the treasury and treasury ratio, and a function to calculate the treasury amount.
 * @dev It also contains external functions to get the treasury address and treasury ratio.
 * @dev The maximum treasury ratio is set to 1e18.
 * @author Aspida engineer
 */
abstract contract CoreTreasury {
    uint256 internal constant MAX_TREASURY_RATIO = 1e18;

    // The address of the treasury
    address internal treasury_;

    // The treasury ratio
    uint256 internal treasuryRatio_;

    /**
     * @dev Emitted when the treasury address is set
     */
    event SetTreasury(address treasury);

    /**
     * @dev Emitted when the treasury ratio is set
     */
    event SetTreasuryRatio(uint256 treasuryRatio);

    /**
     * @dev Sets the treasury address.
     * @param _treasury The address of the treasury.
     */
    function _setTreasuryInternal(address _treasury) internal {
        require(_treasury != address(0) && _treasury != treasury_, "_setTreasuryInternal: Invalid treasury");
        treasury_ = _treasury;
        emit SetTreasury(_treasury);
    }

    /**
     * @dev Sets the treasury ratio.
     * @param _treasuryRatio The treasury ratio.
     */
    function _setTreasuryRatioInternal(uint256 _treasuryRatio) internal {
        require(_treasuryRatio <= MAX_TREASURY_RATIO, "_setTreasuryRatioInternal: TreasuryRatio too large");
        require(_treasuryRatio != treasuryRatio_, "_setTreasuryRatioInternal: Cannot set the same value");
        treasuryRatio_ = _treasuryRatio;
        emit SetTreasuryRatio(_treasuryRatio);
    }

    /**
     * @dev Calculates the treasury amount.
     * @param _amount The amount to calculate the treasury amount for.
     * @return The treasury amount.
     */
    function _getTreasuryAmount(uint256 _amount) internal view returns (uint256) {
        return (_amount * treasuryRatio_) / MAX_TREASURY_RATIO;
    }

    /**
     * @dev Gets the treasury address.
     * @return The address of the treasury.
     */
    function treasury() external view returns (address) {
        return treasury_;
    }

    /**
     * @dev Gets the treasury ratio.
     * @return The treasury ratio.
     */
    function treasuryRatio() external view returns (uint256) {
        return treasuryRatio_;
    }
}
