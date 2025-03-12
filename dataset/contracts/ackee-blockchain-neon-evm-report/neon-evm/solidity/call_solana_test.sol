// SPDX-License-Identifier: MIT

pragma solidity >= 0.7.0;
pragma abicoder v2;
import './SPLToken.sol';
import './call_solana.sol';

SPLToken constant _splToken = SPLToken(0xFf00000000000000000000000000000000000004);
CallSolana constant _callSolana = CallSolana(0xFF00000000000000000000000000000000000006);

contract Test {
    uint256 balance;

    function reverse(uint64 input) internal pure returns (uint64 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00) >> 8) |
            ((v & 0x00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000) >> 16) |
            ((v & 0x0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    function getNeonAddress(address addr) internal returns (bytes32 owner) {
        bytes4 selector = bytes4(keccak256("getNeonAddress(address)"));
        assembly {
            let buff := mload(0x40)
            let pos := buff

            mstore(pos, selector)
            pos := add(pos, 4)
            
            mstore(pos, addr)
            pos := add(pos, 32)

            let length := sub(pos, buff)
            mstore(0x40, pos)

            let success := call(5000, 0xFF00000000000000000000000000000000000006, 0, buff, length, buff, 0x20)
            owner := mload(buff)

            mstore(0x40, buff)
        }
    }

    constructor() {
        // TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
        bytes32 program_id = 0x06ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a9;

        // bytes32 d = 0x6134f00584594e09f9f664be8195ce25deb2a92e3022ef6e5b1d9ad9c2a03a33;
        // bytes memory data = abi.encodePacked(d, true, false);

        bytes32 salt = _salt(msg.sender);

        // //bytes32 resource = _callSolana.getResourceAddress(0x00);
        bytes32 resource = _callSolana.createResource(salt, 165, 6960*165, program_id);    // FwBENPdrTaxftBCnvXNDAyMAk4yYgZjhwqd7xvDNEDpG
        bytes32 mint = 0xf396da383e57418540f8caa598584f49a3b50d256f75cb6d94d101681d6d9d21; // HPsV9Deocecw3GeZv1FkAPNCBRfuVyfw9MMwjwRe1xaU
        //bytes32 owner = _callSolana.getNeonAddress(address(this));                         // 4rcXs8Z5PJCdiR6nj6G8BiGCwsf16wseYCyE54o7t7UA
        bytes32 owner = getNeonAddress(address(this));
        bytes32 rent = 0x06a7d517192c5c51218cc94c3d4af17f58daee089ba1fd44e3dbd98a00000000; // SysvarRent111111111111111111111111111111111

        { // Call SPLToken::InitailizeAccount() for resource,mint,owner,rent accounts
            bytes4 selector = bytes4(keccak256("execute(uint64,bytes)"));
            bool success;
            assembly {
                let buff := mload(0x40)             // the head of heap
                let pos := buff
                
                // selector
                mstore(pos, selector)
                pos := add(pos, 4)

                // required_lamports
                mstore(pos, 0)
                pos := add(pos, 32)

                // offset for instruction
                mstore(pos, sub(add(pos, 28), buff))
                pos := add(pos, 32)
                let size_pos := pos
                pos := add(pos, 32)

                // program_id
                mstore(pos, program_id)
                pos := add(pos, 32)

                // len(accounts)
                mstore(pos, 0)
                mstore8(pos, 4)
                pos := add(pos, 8)

                // AccountMeta(resource, false, true)
                mstore(pos, resource)
                mstore8(add(pos, 32), 0)
                mstore8(add(pos, 33), 1)
                pos := add(pos, 34)

                // AccountMeta(mint, false, false)
                mstore(pos, mint)
                mstore8(add(pos, 32), 0)
                mstore8(add(pos, 33), 0)
                pos := add(pos, 34)

                // AccountMeta(owner, false, false)
                mstore(pos, owner)
                mstore8(add(pos, 32), 0)
                mstore8(add(pos, 33), 0)
                pos := add(pos, 34)

                // AccountMeta(rent, false, false)
                mstore(pos, rent)
                mstore8(add(pos, 32), 0)
                mstore8(add(pos, 33), 0)
                pos := add(pos, 34)

                // len(instruction_data)
                mstore(pos, 0)
                mstore8(pos, 1)
                pos := add(pos, 8)

                // instruction_data: InitializeAccount
                mstore8(pos, 1)
                pos := add(pos, 1)

                mstore(size_pos, sub(sub(pos, size_pos), 32))
                let length := sub(pos, buff)
                mstore(0x40, pos)
                success := call(5000, 0xFF00000000000000000000000000000000000006, 0, buff, length, buff, 0x20)
                mstore(0x40, buff)
            }
            if (success == false) {
                revert("Can't initailize resource");
            }
        }

        bytes32 source = 0xf567a23ec5b9f6a543bb3fd8d5ab7f2d4682fcb1908b755b477f116ec2925af8; // HWxYLBFfPxzrtGTKZL3VEN9dTDBz7qDgFXJVcw8zFkfq
        {
            bytes4 selector = bytes4(keccak256("execute(uint64,bytes)"));
            uint amount = uint(reverse(1000)) << (256-64);
            bool success;
            assembly {
                let buff := mload(0x40)
                let pos := buff
                
                // selector
                mstore(pos, selector)
                pos := add(pos, 4)

                // required_lamports
                mstore(pos, 0)
                pos := add(pos, 32)

                // offset for instruction
                mstore(pos, sub(add(pos, 28), buff))
                pos := add(pos, 32)
                let size_pos := pos
                pos := add(pos, 32)

                // program_id
                mstore(pos, program_id)
                pos := add(pos, 32)

                // len(accounts)
                mstore(pos, 0)
                mstore8(pos, 3)
                pos := add(pos, 8)

                // AccountMeta(resource, false, true)
                mstore(pos, source)
                mstore8(add(pos, 32), 0)
                mstore8(add(pos, 33), 1)
                pos := add(pos, 34)

                // AccountMeta(mint, false, false)
                mstore(pos, resource)
                mstore8(add(pos, 32), 0)
                mstore8(add(pos, 33), 1)
                pos := add(pos, 34)

                // AccountMeta(owner, false, false)
                mstore(pos, owner)
                mstore8(add(pos, 32), 1)
                mstore8(add(pos, 33), 0)
                pos := add(pos, 34)

                // len(instruction_data)
                mstore(pos, 0)
                mstore8(pos, 9)
                pos := add(pos, 8)

                // instruction_data: Transfer
                mstore8(pos, 3)
                mstore(add(pos, 1), amount)
                pos := add(pos, 9)

                mstore(size_pos, sub(sub(pos, size_pos), 32))
                let length := sub(pos, buff)
                mstore(0x40, pos)
                success := call(5000, 0xFF00000000000000000000000000000000000006, 0, buff, length, buff, 0x20)
                mstore(0x40, buff)
            }
            if (success == false) {
                revert("Can't initailize resource");
            }
        }

        balance = balanceOf(msg.sender);
    }

    function balanceOf(address who) public view returns (uint256) {
        bytes32 account = _solanaAccount(who);
        return _splToken.getAccount(account).amount;
    }

    function _salt(address account) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }

    function _solanaAccount(address account) internal pure returns (bytes32) {
        return _splToken.findAccount(_salt(account));
    }
}


/*
solana airdrop 1
spl-token create-account HPsV9Deocecw3GeZv1FkAPNCBRfuVyfw9MMwjwRe1xaU
spl-token mint HPsV9Deocecw3GeZv1FkAPNCBRfuVyfw9MMwjwRe1xaU 1000000 HWxYLBFfPxzrtGTKZL3VEN9dTDBz7qDgFXJVcw8zFkfq --mint-authority ~/neonlabs/neon-evm.git/ci/evm_loader-keypair.json
spl-token approve HWxYLBFfPxzrtGTKZL3VEN9dTDBz7qDgFXJVcw8zFkfq 1000000 4rcXs8Z5PJCdiR6nj6G8BiGCwsf16wseYCyE54o7t7UA
spl-token display HWxYLBFfPxzrtGTKZL3VEN9dTDBz7qDgFXJVcw8zFkfq
*/
