pragma solidity 0.5.16;
import "openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol";
import "./interfaces/ITokenPermission.sol";

contract TokenPermissionConfig is ITokenPermission, Ownable {
    address refuelTokenPermission;
    address terminateTokenPermission;
    uint256 refuelTokenAmount;
    uint256 terminateTokenAmount;
    constructor(
        address _refuelTokenPermission,
        address _terminateTokenPermission,
        uint256 _refuelTokenAmount,
        uint256 _terminateTokenAmount
    ) public {
        setParams(_refuelTokenPermission, _terminateTokenPermission, _refuelTokenAmount, _terminateTokenAmount);
    }

    function setParams(
        address _refuelTokenPermission,
        address _terminateTokenPermission,
        uint256 _refuelTokenAmount,
        uint256 _terminateTokenAmount
    ) public onlyOwner {
        refuelTokenPermission = _refuelTokenPermission;
        terminateTokenPermission = _terminateTokenPermission;
        refuelTokenAmount = _refuelTokenAmount;
        terminateTokenAmount = _terminateTokenAmount;
    }

    function getRefuelTokenPermission() external view returns (address) {
        return refuelTokenPermission;
    }

    function getRefuelTokenAmount() external view returns (uint256) {
        return refuelTokenAmount;
    }

    function getTerminateTokenPermission() external view returns (address) {
        return terminateTokenPermission;
    }

    function getTerminateTokenAmount() external view returns (uint256) {
        return terminateTokenAmount;
    }
}