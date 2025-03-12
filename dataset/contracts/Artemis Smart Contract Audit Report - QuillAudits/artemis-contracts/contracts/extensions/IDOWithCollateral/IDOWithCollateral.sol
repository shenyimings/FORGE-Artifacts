//SPDX-License-Identifier: Unlicensed
import "../../IDO.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IIDOWithCollateral.sol";
pragma solidity ^0.8.0;
abstract contract IDOWithCollateral is IIDOWithCollateral, IDO, AccessControlEnumerable {
    bytes32 public override COLLATERALISED_ROLE = keccak256("COLLATERALISED_ROLE");
    CollateralInfo _collateralInfo;
    constructor(CollateralInfo memory collateralInfo) {
        _collateralInfo = collateralInfo;
    }
    function getCollateralInfo() external view override returns(CollateralInfo memory) {
        return _collateralInfo;
    }
    function collateralise() external override {
        require(block.timestamp < _parameters.buyingStartsAt, "Buying has not already started.");
        require(!hasRole(COLLATERALISED_ROLE, msg.sender), "Already collateralised.");
        _collateralInfo.token.transferFrom(msg.sender, address(this), _collateralInfo.amount);
        _grantRole(COLLATERALISED_ROLE, msg.sender);
        emit Collateralised(msg.sender);
    }
    function refundCollateral() external override {
        require(block.timestamp >= _parameters.buyingEndsAt, "Buying has not ended yet.");
        require(hasRole(COLLATERALISED_ROLE, msg.sender), "Not collateralised.");
        _collateralInfo.token.transfer(msg.sender, _collateralInfo.amount);
        _revokeRole(COLLATERALISED_ROLE, msg.sender);
        emit CollateralRefunded(msg.sender);
    }
    function _beforeContribution(address addr, uint amount) internal virtual override {
        require(hasRole(COLLATERALISED_ROLE, addr), "User has not collateralised.");
        super._beforeContribution(addr, amount);
    }
}