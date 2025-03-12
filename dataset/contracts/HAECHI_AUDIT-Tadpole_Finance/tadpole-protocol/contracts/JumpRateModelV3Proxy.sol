pragma solidity ^0.5.16;

import "./InterestRateModel.sol";
import "./JumpRateModelV3Storage.sol";
import "./JumpRateModelV3Implementation.sol";
/**
 * @title InterestRateProxy
 * @dev Storage for the InterestRateModel 
 */
contract InterestRateProxy is InterestRateModelStorage, JumpRateModelV3Storage {
    
    using SafeMath for uint;

    /**
      * @notice Emitted when pendingComptrollerImplementation is accepted, which means comptroller implementation is updated
      */
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
      * @notice Emitted when pendingAdmin is accepted, which means admin is updated
      */
    event NewAdmin(address oldAdmin, address newAdmin);

    constructor(JumpRateModelV3 newImplementation, uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_) public {
        // Set admin to caller
        admin = msg.sender;
        owner = msg.sender;

        require(newImplementation.isJumpRateModelV3() == true, "invalid implementation");
        implementation = address(newImplementation);

        baseRatePerBlock = baseRatePerYear.div(blocksPerYear);
        multiplierPerBlock = (multiplierPerYear.mul(1e18)).div(blocksPerYear.mul(kink_));
        jumpMultiplierPerBlock = jumpMultiplierPerYear.div(blocksPerYear);
        kink = kink_;

        emit NewImplementation(address(0), implementation);
    }

    /*** Admin Functions ***/
    function _setImplementation(JumpRateModelV3 newImplementation) public {

        require(msg.sender==admin, "UNAUTHORIZED");

        require(newImplementation.isJumpRateModelV3() == true, "invalid implementation");

        address oldImplementation = implementation;

        implementation = address(newImplementation);

        emit NewImplementation(oldImplementation, implementation);

    }


    /**
      * @notice Transfer of admin rights
      * @dev Admin function to change admin
      * @param newAdmin New pending admin.
      */
    function _setAdmin(address newAdmin) public {
        // Check caller = admin
        require(msg.sender==admin, "UNAUTHORIZED");

        // Save current value, if any, for inclusion in log
        address oldAdmin = admin;

        // Store pendingAdmin with value newPendingAdmin
        admin = newAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewAdmin(oldAdmin, newAdmin);

    }

    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    function () payable external {
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
              let free_mem_ptr := mload(0x40)
              returndatacopy(free_mem_ptr, 0, returndatasize)

              switch success
              case 0 { revert(free_mem_ptr, returndatasize) }
              default { return(free_mem_ptr, returndatasize) }
        }
    }
}
