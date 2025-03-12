pragma solidity ^0.8.0;

import "src/factory/KernelFactory.sol";
import "src/validator/ECDSAValidator.sol";
import "src/factory/ECDSAKernelFactory.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployKernel is Script {
    address internal constant DETERMINISTIC_CREATE2_FACTORY = 0x7A0D94F55792C434d74a40883C6ed8545E406D12;

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);
        bytes memory bytecode = type(KernelFactory).creationCode;
        bool success;
        bytes memory returnData;
        (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(
            abi.encodePacked(bytecode, abi.encode(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789)))
        );
        require(success, "Failed to deploy KernelFactory");
        console.logBytes(returnData);
        address kernelFactory = address(bytes20(returnData));
        console.log("KernelFactory deployed at: %s", kernelFactory);

        // bytecode = type(ECDSAValidator).creationCode;
        // (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(abi.encodePacked(bytecode));
        // require(success, "Failed to deploy ECDSAValidator");
        // address validator = address(bytes20(returnData));
        // console.log("ECDSAValidator deployed at: %s", validator);

        address validator = 0x180D6465F921C7E0DEA0040107D342c87455fFF5;

        bytecode = type(ECDSAKernelFactory).creationCode;
        (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(
            abi.encodePacked(
                bytecode,
                abi.encode(kernelFactory),
                abi.encode(address(validator)),
                abi.encode(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789))
            )
        );
        require(success, "Failed to deploy ECDSAKernelFactory");
        address ecdsaFactory = address(bytes20(returnData));
        console.log("ECDSAKernelFactory deployed at: %s", ecdsaFactory);
        vm.stopBroadcast();
    }
}

// Old ones with the TempKernel template
// KernelFactory deployed at: 0x5CE6FEF9172915a4D9A7C8B1cC9B5B279a7511e3
// ECDSAValidator deployed at: 0x180D6465F921C7E0DEA0040107D342c87455fFF5
// ECDSAKernelFactory deployed at: 0x7806D99EE789162E9609E979099D043f2bEff18f

// New ones after changing the template
// KernelFactory deployed at: 0x62095e340967c464152c79a1cC26a27e11e57e5c
// ECDSAKernelFactory deployed at: 0xf7d5E0c8bDC24807c8793507a2aF586514f4c46e
