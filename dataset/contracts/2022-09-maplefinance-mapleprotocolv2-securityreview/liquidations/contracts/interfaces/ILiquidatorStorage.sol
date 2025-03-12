// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface ILiquidatorStorage {

    /**
     *  @dev    Returns the address of the collateral asset.
     *  @return collateralAsset_ Address of the asset used as collateral.
     */
    function collateralAsset() external view returns (address collateralAsset_);

    /**
     *  @dev    Returns the amount of collateral yet to be liquidated.
     *  @return collateralRemaining_ Amunt of collateral remaining to be liquidated.
     */
    function collateralRemaining() external view returns (uint256 collateralRemaining_);

    /**
     *  @dev    Returns the address of the funding asset.
     *  @return fundsAsset_ Address of the asset used for providing funds.
     */
    function fundsAsset() external view returns (address fundsAsset_);

    /**
     *  @dev    Returns the address of the loan manager contract.
     *  @return loanManager_ Address of the loan manager.
     */
    function loanManager() external view returns (address loanManager_);


}
