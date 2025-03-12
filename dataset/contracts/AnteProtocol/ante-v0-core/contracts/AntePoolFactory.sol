// SPDX-License-Identifier: GPL-3.0-only

// ┏━━━┓━━━━━┏┓━━━━━━━━━┏━━━┓━━━━━━━━━━━━━━━━━━━━━━━
// ┃┏━┓┃━━━━┏┛┗┓━━━━━━━━┃┏━━┛━━━━━━━━━━━━━━━━━━━━━━━
// ┃┗━┛┃┏━┓━┗┓┏┛┏━━┓━━━━┃┗━━┓┏┓┏━┓━┏━━┓━┏━┓━┏━━┓┏━━┓
// ┃┏━┓┃┃┏┓┓━┃┃━┃┏┓┃━━━━┃┏━━┛┣┫┃┏┓┓┗━┓┃━┃┏┓┓┃┏━┛┃┏┓┃
// ┃┃ ┃┃┃┃┃┃━┃┗┓┃┃━┫━┏┓━┃┃━━━┃┃┃┃┃┃┃┗┛┗┓┃┃┃┃┃┗━┓┃┃━┫
// ┗┛ ┗┛┗┛┗┛━┗━┛┗━━┛━┗┛━┗┛━━━┗┛┗┛┗┛┗━━━┛┗┛┗┛┗━━┛┗━━┛
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pragma solidity ^0.7.0;

import "./AntePool.sol";
import "./interfaces/IAnteTest.sol";
import "./interfaces/IAntePoolFactory.sol";

/// @title Ante V0.5 Ante Pool Factory smart contract
/// @notice Contract that creates an AntePool wrapper for an AnteTest
contract AntePoolFactory is IAntePoolFactory {
    /// @inheritdoc IAntePoolFactory
    mapping(address => address) public override poolMap;
    /// @inheritdoc IAntePoolFactory
    address[] public override allPools;

    /// @inheritdoc IAntePoolFactory
    function createPool(address testAddr) external override returns (address testPool) {
        // Checks that a non-zero AnteTest address is passed in and that
        // an AntePool has not already been created for that AnteTest
        require(testAddr != address(0), "ANTE: Test address is 0");
        require(poolMap[testAddr] == address(0), "ANTE: Pool already created");

        IAnteTest anteTest = IAnteTest(testAddr);

        bytes memory bytecode = type(AntePool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(testAddr));

        assembly {
            testPool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        poolMap[testAddr] = testPool;
        allPools.push(testPool);

        AntePool(testPool).initialize(anteTest);

        emit AntePoolCreated(testAddr, testPool);
    }
}
