// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

contract TestExecutor {
    receive() external payable {}

    uint256 public moduleCount;
    mapping(address => bool) public modules;

    function enableModule(address _module) external {
        if (modules[_module]) return;
        moduleCount++;
        modules[_module] = true;
    }

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory
    ) external payable returns (bool success) {
        exec(payable(to), value, data, operation);
        return true;
    }

    function exec(
        address payable to,
        uint256 value,
        bytes calldata data,
        uint256 operation
    ) public {
        bool success;
        bytes memory response;
        if (operation == 0) (success, response) = to.call{value: value}(data);
        else (success, response) = to.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(response, 0x20), mload(response))
            }
        }
    }

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success) {
        require(modules[msg.sender], "TestExecutor: Not authorized");
        if (operation == 1) (success, ) = to.delegatecall(data);
        else (success, ) = payable(to).call{value: value}(data);
    }
}
