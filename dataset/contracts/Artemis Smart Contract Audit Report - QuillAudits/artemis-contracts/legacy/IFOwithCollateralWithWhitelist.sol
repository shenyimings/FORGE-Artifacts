//SPDX-License-Identifier: Unlicensed
import "./IFOwithCollateralWithHook.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/AccessControl.sol";
pragma solidity ^0.6.0;
contract IDOwithCollateralWithWhitelist is IFOwithCollateralWithHook, AccessControl {
    bytes32 public WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");
    bytes32 public WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");
    constructor(IERC20 _lpToken,
        IERC20 _offeringToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _offeringAmount,
        uint256 _raisingAmount,
        address _adminAddress,
        IERC20 _collateralToken,
        uint256 _requiredCollateralAmount) public IFOwithCollateralWithHook(_lpToken,_offeringToken,
         _startBlock,
         _endBlock,
         _offeringAmount,
         _raisingAmount,
         _adminAddress,
         _collateralToken,
         _requiredCollateralAmount) {
        _setupRole(DEFAULT_ADMIN_ROLE,msg.sender);
        _setRoleAdmin(WHITELISTED_ROLE, WHITELISTER_ROLE);
    }
    function _beforeDeposit(address addr, uint amount) internal virtual override {
        require(hasRole(WHITELISTED_ROLE, addr), "User has not been whitelisted.");
        super._beforeDeposit(addr,amount);
    }
    function whitelistAddresses(address[] memory addresses) external {
        for(uint i; i < addresses.length; i ++) {
            grantRole(WHITELISTED_ROLE,addresses[i]);
        }
    }
}