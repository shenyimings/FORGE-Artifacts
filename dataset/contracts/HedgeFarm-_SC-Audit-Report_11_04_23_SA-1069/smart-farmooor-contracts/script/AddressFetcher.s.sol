pragma solidity ^0.8.0;

import "../contracts/yield/interface/ISmartFarmooor.sol";
import "../contracts/yield/interface/IYieldModule.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AddressFetcher {
    address public smartFarmooorAddress;
    address public smartFarmooorImplAddress;
    address public stargateModuleAddress;
    address public stargateModuleImplAddress;
    address public benqiModuleAddress;
    address public benqiModuleImplAddress;
    address public bankerJoeModuleAddress;
    address public bankerJoeModuleImplAddress;
    address public aaveModuleAddress;
    address public aaveModuleImplAddress;

    bool STARGATE_ACTIVE_CURRENT_VALUE;
    bool BENQI_ACTIVE_CURRENT_VALUE;
    bool BANKER_JOE_ACTIVE_CURRENT_VALUE;
    bool AAVE_ACTIVE_CURRENT_VALUE;

    bytes32 private STARGATE_YIELD_MODULE = keccak256(bytes("StargateYieldModule"));
    bytes32 private BENQI_YIELD_MODULE = keccak256(bytes("BenqiYieldModule"));
    bytes32 private BANKER_JOE_YIELD_MODULE = keccak256(bytes("BankerJoeYieldModule"));
    bytes32 private AAVE_YIELD_MODULE = keccak256(bytes("AaveV3YieldModule"));

    

    function fetchAddresses(address _smartFarmooorAddress) public {
        smartFarmooorAddress = _smartFarmooorAddress;
        smartFarmooorImplAddress = ISmartFarmooor(smartFarmooorAddress).getImplementation();
        uint256 numberOfModules = ISmartFarmooor(smartFarmooorAddress).numberOfModules();
        for (uint256 i = 0; i < numberOfModules; i++) {
            (IYieldModule module,) = ISmartFarmooor(smartFarmooorAddress).yieldOptions(i);
            bytes32 moduleName = keccak256(bytes(module.name()));
            if (moduleName == STARGATE_YIELD_MODULE){
                stargateModuleAddress = address(module);
                stargateModuleImplAddress = module.getImplementation();
                STARGATE_ACTIVE_CURRENT_VALUE = true;
            } else if (moduleName == BENQI_YIELD_MODULE){
                benqiModuleAddress = address(module);
                benqiModuleImplAddress = module.getImplementation();
                BENQI_ACTIVE_CURRENT_VALUE = true;
            } else if (moduleName == BANKER_JOE_YIELD_MODULE){
                bankerJoeModuleAddress = address(module);
                bankerJoeModuleImplAddress = module.getImplementation();
                BANKER_JOE_ACTIVE_CURRENT_VALUE = true;
            } else if (moduleName == AAVE_YIELD_MODULE){
                aaveModuleAddress = address(module);
                aaveModuleImplAddress = module.getImplementation();
                AAVE_ACTIVE_CURRENT_VALUE = true;
            } else {
                revert("AddressFetcher: unknown module");
            }
        }
    }

}