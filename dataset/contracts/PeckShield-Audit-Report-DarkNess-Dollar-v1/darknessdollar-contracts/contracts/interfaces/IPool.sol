// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPool {
    function targetCollateralRatio() external view returns (uint256);

    function targetDarkOverDarkShareRatio() external view returns (uint256);

    function calcMintInput(uint256 _dollarAmount) external view returns (uint256 _mainCollateralAmount, uint256 _darkAmount, uint256 _shareAmount, uint256 _darkFee, uint256 _shareFee);

    function calcMintOutputFromCollaterals(uint256[] memory _collateralAmounts) external view returns (uint256 _dollarAmount, uint256 _darkAmount, uint256 _shareAmount, uint256 _darkFee, uint256 _shareFee);

    function calcMintOutputFromDark(uint256 _darkAmount) external view returns (uint256 _dollarAmount, uint256 _mainCollateralAmount, uint256 _shareAmount, uint256 _darkFee, uint256 _shareFee);

    function calcMintOutputFromShare(uint256 _shareAmount) external view returns (uint256 _dollarAmount, uint256 _mainCollateralAmount, uint256 _darkAmount, uint256 _darkFee, uint256 _shareFee);

    function calcRedeemOutput(uint256 _dollarAmount) external view returns (uint256[] memory _collateralAmounts, uint256 _darkAmount, uint256 _shareAmount, uint256 _darkFee, uint256 _shareFee);

    function getCollateralPrice(uint256 _index) external view returns (uint256);

    function getDollarPrice() external view returns (uint256);

    function getDarkPrice() external view returns (uint256);

    function getSharePrice() external view returns (uint256);

    function getRedemptionOpenTime(address _account) external view returns (uint256);

    function unclaimed_pool_collateral(uint256) external view returns (uint256);

    function unclaimed_pool_dark() external view returns (uint256);

    function unclaimed_pool_share() external view returns (uint256);

    function mintingLimitHourly() external view returns (uint256 _limit);

    function mintingLimitDaily() external view returns (uint256 _limit);

    function calcMintableDollarHourly() external view returns (uint256 _limit);

    function calcMintableDollarDaily() external view returns (uint256 _limit);

    function calcMintableDollar() external view returns (uint256 _dollarAmount);

    function calcRedeemableDollarHourly() external view returns (uint256 _limit);

    function calcRedeemableDollarDaily() external view returns (uint256 _limit);

    function calcRedeemableDollar() external view returns (uint256 _dollarAmount);

    function updateTargetCollateralRatio() external;

    function updateTargetDarkOverShareRatio() external;
}
