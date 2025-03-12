// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./IPool.sol";

interface IGasPool {
    // --- Events ---
    event LUSDAddressChanged(address _lusdAddress);
    event TroveManagerAddressChanged(address _troveManagerAddress);
    event ReturnToLiquidator(address indexed to, uint256 amount, uint256 timestamp);
    event CoreControllerAddressChanged(address _coreControllerAddress);
    event BorrowerOperationsAddressChanged(address _borrowerOperationsAddress);
    event LUSDBurnt(uint256 amount, uint256 timestamp);
    
    // --- Functions ---
    function setAddresses(
        address _troveManagerAddress, 
        address _lusdTokenAddress, 
        address _borrowerOperationAddress, 
        address _coreControllerAddress
    ) external;
    function returnToLiquidator(address _account, uint256 amount) external;
    function burnLUSD(uint256 _amount) external;
}
