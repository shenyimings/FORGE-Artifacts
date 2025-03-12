// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IACLManager {
    function addAddressAdmin(address admin) external;

    function isAddressAdmin(address admin) external view returns (bool);
    
    function removeAddressAdmin(address admin) external;
    
    function addEmergencyAdmin(address admin) external;
    
    function isEmergencyAdmin(address admin) external view returns (bool);
    
    function removeEmergencyAdmin(address admin) external;
    
    function addGovernance(address admin) external;
    
    function isGovernance(address admin) external view returns (bool);

    function removeGovernance(address admin) external;

    function addPoolAdmin(address admin) external;

    function isPoolAdmin(address admin) external view returns (bool);

    function removePoolAdmin(address admin) external;

    function addLiquidator(address liquidator) external;

    function isLiquidator(address liquidator) external view returns (bool);

    function removeLiquidator(address liquidator) external;

    function addLiquidationOperator(address address_) external;

    function isLiquidationOperator(address address_) external view returns (bool);

    function removeLiquidationOperator(address address_) external;

    function addAirdropOperator(address address_) external;

    function isAirdropOperator(address address_) external view returns (bool);

    function removeAirdropOperator(address address_) external;
}
