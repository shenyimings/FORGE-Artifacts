pragma solidity 0.5.10;

interface CollateralInterface {
    function onDemandSpv() external view returns(address);
    function collateral(bytes32 loan) external view returns (uint256);
    function refundableCollateral(bytes32 loan) external view returns (uint256);
    function seizableCollateral(bytes32 loan) external view returns (uint256);
    function temporaryRefundableCollateral(bytes32 loan) external view returns (uint256);
    function temporarySeizableCollateral(bytes32 loan) external view returns (uint256);
    function setCollateral(bytes32 loan, uint256 refundableCollateral_, uint256 seizableCollateral_) external;
    function requestSpv(bytes32 loan) external;
    function cancelSpv(bytes32 loan) external;
}
