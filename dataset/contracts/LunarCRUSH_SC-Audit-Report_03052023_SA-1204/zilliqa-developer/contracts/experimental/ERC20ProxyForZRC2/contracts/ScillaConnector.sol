// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

library ScillaConnector {
    uint private constant CALL_SCILLA_WITH_THE_SAME_SENDER = 1;
    uint private constant SCILLA_CALL_PRECOMPILE_ADDRESS = 0x5a494c53;
    uint private constant SCILLA_STATE_READ_PRECOMPILE_ADDRESS = 0x5a494c92;

    /**
     * @dev Calls a ZRC2 contract function with one argument
     * @param target The address of the ZRC2 contract
     * @param tran_name The name of the function to call
     * @param arg1 The first argument to the function
     */
    function call(
        address target,
        string memory tran_name,
        uint128 arg1
    ) internal {
        bytes memory encodedArgs = abi.encode(
            target,
            tran_name,
            CALL_SCILLA_WITH_THE_SAME_SENDER,
            arg1
        );
        uint256 argsLength = encodedArgs.length;

        assembly {
            let alwaysSuccessForThisPrecompile := call(
                gas(),
                SCILLA_CALL_PRECOMPILE_ADDRESS,
                0,
                add(encodedArgs, 0x20),
                argsLength,
                0x20,
                0
            )
        }
    }


    /**
     * @dev Calls a ZRC2 contract function with two arguments
     * @param target The address of the ZRC2 contract
     * @param tran_name The name of the function to call
     * @param arg1 The first argument to the function
     * @param arg2 The second argument to the function
     */
    function call(
        address target,
        string memory tran_name,
        address arg1,
        uint128 arg2
    ) internal {
        bytes memory encodedArgs = abi.encode(
            target,
            tran_name,
            CALL_SCILLA_WITH_THE_SAME_SENDER,
            arg1,
            arg2
        );
        uint256 argsLength = encodedArgs.length;

        assembly {
            let alwaysSuccessForThisPrecompile := call(
                gas(),
                SCILLA_CALL_PRECOMPILE_ADDRESS,
                0,
                add(encodedArgs, 0x20),
                argsLength,
                0x20,
                0
            )
        }
    }

    /**
     * @dev Calls a ZRC2 contract function with three arguments
     * @param target The address of the ZRC2 contract
     * @param tran_name The name of the function to call on the ZRC2 contract
     * @param arg1 The first argument to the function
     * @param arg2 The second argument to the function
     * @param arg3 The third argument to the function
     */
    function call(
        address target,
        string memory tran_name,
        address arg1,
        address arg2,
        uint128 arg3
    ) internal {
        bytes memory encodedArgs = abi.encode(
            target,
            tran_name,
            CALL_SCILLA_WITH_THE_SAME_SENDER,
            arg1,
            arg2,
            arg3
        );
        uint256 argsLength = encodedArgs.length;

        assembly {
            let alwaysSuccessForThisPrecompile := call(
                gas(),
                SCILLA_CALL_PRECOMPILE_ADDRESS,
                0,
                add(encodedArgs, 0x20),
                argsLength,
                0x20,
                0
            )
        }
    }

    /**
     * @dev Reads a 128 bit integer from a ZRC2 contract
     * @param target The address of the ZRC2 contract
     * @param variable_name The name of the variable to read from the ZRC2 contract
     * @return The value of the variable
     */
    function readUint128(
        address target,
        string memory variable_name
    ) internal view returns (uint128) {
        bytes memory encodedArgs = abi.encode(target, variable_name);
        uint256 argsLength = encodedArgs.length;
        bytes memory output = new bytes(36);

        assembly {
            let alwaysSuccessForThisPrecompile := staticcall(
                gas(),
                SCILLA_STATE_READ_PRECOMPILE_ADDRESS,
                add(encodedArgs, 0x20),
                argsLength,
                add(output, 0x20),
                32
            )
        }

        return abi.decode(output, (uint128));
    }

    /**
     * @dev Reads a 32 bit integer from a ZRC2 contract
     * @param target The address of the ZRC2 contract
     * @param variable_name The name of the variable to read from the ZRC2 contract
     * @return The value of the variable
     */
    function readUint32(
        address target,
        string memory variable_name
    ) internal view returns (uint32) {
        bytes memory encodedArgs = abi.encode(target, variable_name);
        uint256 argsLength = encodedArgs.length;
        bytes memory output = new bytes(36);

        assembly {
            let alwaysSuccessForThisPrecompile := staticcall(
                gas(),
                SCILLA_STATE_READ_PRECOMPILE_ADDRESS,
                add(encodedArgs, 0x20),
                argsLength,
                add(output, 0x20),
                32
            )
        }

        return abi.decode(output, (uint32));
    }

    /**
     * @dev Reads a string from a ZRC2 contract
     * @param target The address of the ZRC2 contract
     * @param variable_name The name of the variable to read from the ZRC2 contract
     * @return retVal The value of the variable
     */
    function readString(
        address target,
        string memory variable_name
    ) internal view returns (string memory retVal) {
        bytes memory encodedArgs = abi.encode(target, variable_name);
        uint256 argsLength = encodedArgs.length;
        bool success;
        bytes memory output = new bytes(128);
        uint256 output_len = output.length - 4;
        assembly {
            success := staticcall(
                gas(),
                SCILLA_STATE_READ_PRECOMPILE_ADDRESS,
                add(encodedArgs, 0x20),
                argsLength,
                add(output, 0x20),
                output_len
            )
        }
        require(success);

        (retVal) = abi.decode(output, (string));
        return retVal;
    }

    /**
     * @dev Reads a 128 bit integer from a map in a ZRC2 contract
     * @param variable_name The name of the map in the ZRC2 contract
     * @param addressMapKey The key to the map
     * @return The value associated with the key in the map
     */
    function readMapUint128(
        address target,
        string memory variable_name,
        address addressMapKey
    ) internal view returns (uint128) {
        bytes memory encodedArgs = abi.encode(
            target,
            variable_name,
            addressMapKey
        );
        uint256 argsLength = encodedArgs.length;
        bytes memory output = new bytes(36);

        assembly {
            let alwaysSuccessForThisPrecompile := staticcall(
                gas(),
                SCILLA_STATE_READ_PRECOMPILE_ADDRESS,
                add(encodedArgs, 0x20),
                argsLength,
                add(output, 0x20),
                32
            )
        }

        return abi.decode(output, (uint128));
    }

    /**
     * @dev Reads a 128 bit integer from a nested map in a ZRC2 contract
     * @param target The address of the ZRC2 contract
     * @param variable_name The name of the map in the ZRC2 contract
     * @param firstMapKey The first key to the map
     * @param secondMapKey The second key to the map
     * @return The value associated with the keys in the map
     */
    function readNestedMapUint128(
        address target,
        string memory variable_name,
        address firstMapKey,
        address secondMapKey
    ) internal view returns (uint128) {
        bytes memory encodedArgs = abi.encode(
            target,
            variable_name,
            firstMapKey,
            secondMapKey
        );
        uint256 argsLength = encodedArgs.length;
        bytes memory output = new bytes(36);

        assembly {
            let alwaysSuccessForThisPrecompile := staticcall(
                gas(),
                SCILLA_STATE_READ_PRECOMPILE_ADDRESS,
                add(encodedArgs, 0x20),
                argsLength,
                add(output, 0x20),
                32
            )
        }

        return abi.decode(output, (uint128));
    }
}
