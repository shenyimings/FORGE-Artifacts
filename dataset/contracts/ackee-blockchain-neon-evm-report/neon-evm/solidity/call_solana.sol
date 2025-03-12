// SPDX-License-Identifier: MIT

pragma solidity >= 0.7.0;
pragma abicoder v2;

interface CallSolana {

    struct Instruction {
        bytes32 program_id;
        AccountMeta[] accounts;
        bytes instruction_data;
    }

    struct AccountMeta {
        bytes32 account;
        bool is_signer;
        bool is_writable;
    }

    // Returns Solana address for Neon address.
    // Calculates as PDA([ACCOUNT_SEED_VERSION, Neon-address], evm_loader_id)
    function getNeonAddress(address) external view returns (bytes32);
    
    
    // Returns Solana address of resource for contracts.
    // Calculates as PDA([ACCONT_SEED_VERSION, "ContractData", msg.sender, salt], evm_loader_id)
    function getResourceAddress(bytes32 salt) external view returns (bytes32);
    
    
    // Creates resource with specified salt.
    // Return the Solana address of the created resource (see `getResourceAddress`)
    function createResource(bytes32 salt, uint64 space, uint64 lamports, bytes32 owner) external returns (bytes32);
    
    
    // Returns Solana PDA generated from specified program_id and seeds
    function getSolanaPDA(bytes32 program_id, bytes memory seeds) external view returns (bytes32);
    
    
    // Returns Solana address of the external authority.
    // Calculates as PDA([ACCOUNT_SEED_VERSION, "AUTH", msg.sender, salt], evm_loader_id)
    function getExtAuthority(bytes32 salt) external view returns (bytes32);
    
    
    // Return Solana address for payer account (if instruction required some account to funding new created accounts)
    // Calculates as PDA([ACCOUNT_SEED_VERSION, "PAYER", msg.sender], evm_loader_id)
    function getPayer() external view returns (bytes32);


    // Execute the instruction with a call to the Solana program.
    // Guarantees successful execution of call after a success return.
    // Note: If the call was unsuccessful, the transaction fails (due to Solana's behaviour).
    // The `lamports` parameter specifies the amount of lamports that can be required to create new accounts during execution.
    //   This lamports transferred to `payer`-account (see `getPayer()` function) before the call.
    // - `instruction` - instruction which should be executed
    // This method uses PDA for sender to authorize the operation (`getNeonAddress(msg.sender)`)
    // Returns the returned data of the executed instruction (if program returned the data is equal to the program_id of the instruction)
    function execute(uint64 lamports, Instruction memory instruction) external returns (bytes memory);


    // Execute the instruction with call to the Solana program.
    // Guarantees successful execution of call after a success return.
    // Note: If the call was unsuccessful, the transaction fails (due to Solana's behaviour).
    // The `lamports` parameter specifies the amount of lamports that can be required to create new accounts during execution.
    //   This lamports transferred to `payer`-account (see `getPayer()` function) before the call.
    // - `salt` - the salt to generate an address of external authority (see `getExtAuthority()` function)
    // - `instruction` - instruction which should be executed
    // This method uses external authority to authorize the operation (`getExtAuthority(salt)`)
    // Returns the returned data of the executed instruction (if program returned the data is equal to the program_id of the instruction)
    function executeWithSeed(uint64 lamports, bytes32 salt, Instruction memory instruction) external returns (bytes memory);
    
    
    // Execute the instruction with a call to the Solana program.
    // Guarantees successful execution of call after a success return.
    // Note: If the call was unsuccessful, the transaction fails (due to Solana's behaviour).
    // The `lamports` parameter specifies the amount of lamports that can be required to create new accounts during execution.
    //   This lamports transferred to `payer`-account (see `getPayer()` function) before the call.
    // - `instruction` - bincode serialized instruction which should be executed
    // This method uses PDA for sender to authorize the operation (`getNeonAddress(msg.sender)`)
    // Returns the returned data of the executed instruction (if program returned the data is equal to the program_id of the instruction)
    function execute(uint64 lamports, bytes memory instruction) external returns (bytes memory);
    
    
    // Execute the instruction with call to the Solana program.
    // Guarantees successful execution of call after a success return.
    // Note: If the call was unsuccessful, the transaction fails (due to Solana's behaviour).
    // The `lamports` parameter specifies the amount of lamports that can be required to create new accounts during execution.
    //   This lamports transferred to `payer`-account (see `getPayer()` function) before the call.
    // - `salt` - the salt to generate an address of external authority (see `getExtAuthority()` function)
    // - `instruction` - bincode serialized instruction which should be executed
    // This method uses external authority to authorize the operation (`getExtAuthority(salt)`)
    // Returns the returned data of the executed instruction (if program returned the data is equal to the program_id of the instruction)
    function executeWithSeed(uint64 lamports, bytes32 salt, bytes memory instruction) external returns (bytes memory);


    // Returns the program_id and returned data of the last executed instruction (if no return data was set returns zeroed bytes)
    // For more information see: https://docs.rs/solana-program/latest/solana_program/program/fn.get_return_data.html
    // Note: This method should be called after a call to `execute`/`executeWithSeed` methods
    function getReturnData() external view returns (bytes32, bytes memory);
}
    
    
/* Note:
    For `execute`/`executeWithSeed` methods which gets instruction in bincode serialized format
    the instruction should be serialized according to Solana bincode serialize rules. It requires
    serialized data in the following form:

    program_id as bytes32
    len(accounts) as uint64le
        account as bytes32
        is_signer as bool
        is_writable as bool
    len(data) as uint64le
        data (see instruction to Solana program)

The optimized way to serailize instruction is write this code on the solidity assembler.
To perform a call to `execute()` and `executeWithSeed()` methods the next code-sample can be helpful:
```solidity
    {
        // TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
        bytes32 program_id = 0x06ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a9;
        bytes32 owner = getNeonAddress(address(this));

        bytes4 selector = bytes4(keccak256("execute(uint64,bytes)"));
        bool success;
        assembly {
            let buff := mload(0x40)    // the head of heap
            let pos := buff            // current write position
            
            // selector
            mstore(pos, selector)      // write the method selector
            pos := add(pos, 4)

            // Write arguments to call the method
            // lamports
            mstore(pos, 0)             // write required lamports
            pos := add(pos, 32)

            // offset for instruction
            // specify the position of serialized instruction relative to start of arguments
            mstore(pos, sub(add(pos, 28), buff))
            pos := add(pos, 32)
            let size_pos := pos        // Save size position of serialized instruction
            pos := add(pos, 32)

            // program_id
            mstore(pos, program_id)
            pos := add(pos, 32)

            // len(accounts)
            mstore(pos, 0)
            mstore8(pos, 4)
            pos := add(pos, 8)

            // For each account in accounts array:
                // AccountMeta(resource, false, true)
                mstore(pos, owner)        // pubkey
                mstore8(add(pos, 32), 1)  // is_signer
                mstore8(add(pos, 33), 0)  // is_writable
                pos := add(pos, 34)

            // len(instruction_data)  if it shorter than 256 bytes
            mstore(pos, 0)            // fill with zero next 32 bytes
            mstore8(pos, 1)           // write the length of data
            pos := add(pos, 8)

            // instruction_data: InitializeAccount
            mstore8(pos, 1)           // Use Solana program instruction to detailed info
            pos := add(pos, 1)

            mstore(size_pos, sub(sub(pos, size_pos), 32))  // write the size of serialized instruction 
            let length := sub(pos, buff)      // calculate the length of arguments
            mstore(0x40, pos)                 // update head of heap
            success := call(5000, 0xFF00000000000000000000000000000000000006, 0, buff, length, buff, 0x20)
            mstore(0x40, buff)                // restore head of heap
        }
        if (success == false) {
            revert("Can't execute instruction");
        }
    }
```
*/
