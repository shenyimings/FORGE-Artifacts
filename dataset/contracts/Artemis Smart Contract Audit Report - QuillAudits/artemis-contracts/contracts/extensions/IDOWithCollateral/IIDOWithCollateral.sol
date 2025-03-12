//SPDX-License-Identifier: Unlicensed
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
pragma solidity ^0.8.0;
struct CollateralInfo {
    IERC20 token;
    uint amount;
}
interface IIDOWithCollateral {
    event Collateralised(address addr);
    event CollateralRefunded(address addr);
    function COLLATERALISED_ROLE() external view returns(bytes32);
    function getCollateralInfo() external view returns(CollateralInfo memory);
    function collateralise() external;
    function refundCollateral() external;
}