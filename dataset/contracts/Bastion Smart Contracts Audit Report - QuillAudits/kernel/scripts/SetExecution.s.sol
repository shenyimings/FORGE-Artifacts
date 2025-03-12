pragma solidity ^0.8.0;

import "src/Kernel.sol";
import "src/executor/BatchActions.sol";
import "src/validator/ECDSAValidator.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract CreateAccount is Script {
    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);

        //Create an instance of the Kernel contract
        Kernel kernel = Kernel(payable(0x21Bcf2cDaAFd8eb972B3296AFf0eF24BD09dc256));

        BatchActions batchActions = BatchActions(0xF3F98574AC89220B5ae422306dC38b947901b421);
        address owner = vm.addr(key);
        console.log("Owner: %s", owner);
        bytes4 selector1 = batchActions.executeBatch.selector;
        bytes4 selector2 = batchActions.approveAndTransfer20Batch.selector;

        address executor = 0xF3F98574AC89220B5ae422306dC38b947901b421;
        ECDSAValidator validator = ECDSAValidator(0x180D6465F921C7E0DEA0040107D342c87455fFF5);
        //Valid until the year 2030
        uint48 validUntil = 1893456000;
        //Valid after now
        uint48 validAfter = uint48(block.timestamp);
        bytes memory enableData = abi.encodePacked(owner);

        kernel.setExecution(selector1, executor, validator, validUntil, validAfter, enableData);
        kernel.setExecution(selector2, executor, validator, validUntil, validAfter, enableData);

        vm.stopBroadcast();
    }
}

// function setExecution(
//     bytes4 _selector,
//     address _executor,
//     IKernelValidator _validator,
//     uint48 _validUntil,
//     uint48 _validAfter,
//     bytes calldata _enableData
// )

//BatchActions.sol executor = 0xF3F98574AC89220B5ae422306dC38b947901b421
//ECDSAKernelFactory = 0xbe8f7d1f134e0570e109C77c4FB70b26861E9d6c
