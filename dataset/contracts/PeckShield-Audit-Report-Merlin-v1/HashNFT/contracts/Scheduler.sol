// contracts/Scheduler.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";

contract Scheduler is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    event CallScheduled(bytes32 id);
    event CallExecuted(bytes32 id);

    uint256 public immutable period;
    uint256 public immutable delay;
    mapping(bytes32 => bool) public queuedOperations;

    constructor(
        address[] memory proposers,
        address[] memory executors,
        uint256 period_,
        uint256 delay_
    ) {
        period = period_;
        delay = delay_;

        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, ADMIN_ROLE);

        // deployer + self administration
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, address(this));

        // register proposers
        for (uint256 i = 0; i < proposers.length; ++i) {
            _setupRole(PROPOSER_ROLE, proposers[i]);
        }

        // register executors
        for (uint256 i = 0; i < executors.length; ++i) {
            _setupRole(EXECUTOR_ROLE, executors[i]);
        }
    }

    function schedule(
        address target,
        uint256 value,
        string memory signature,
        bytes calldata data,
        bytes32 predecessor
    ) public onlyRole(PROPOSER_ROLE) {
        bytes32 id = hashOperation(target, value, signature, data, predecessor);
        require(
            !queuedOperations[id],
            "Scheduler: operation already scheduled"
        );
        queuedOperations[id] = true;
        emit CallScheduled(id);
    }

    function hashOperation(
        address target,
        uint256 value,
        string memory signature,
        bytes calldata data,
        bytes32 predecessor
    ) public pure virtual returns (bytes32 hash) {
        return keccak256(abi.encode(target, value, signature, data, predecessor));
    }

    function execute(
        address target,
        uint256 value,
        string memory signature,
        bytes calldata data,
        bytes32 predecessor
    ) public onlyRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, signature, data, predecessor);
        _beforeCall(id, predecessor);
        _call(id, target, value, signature, data);
        _afterCall(id);
    }

    function _beforeCall(bytes32 id, bytes32 predecessor) private view {
        require(queuedOperations[id], "Scheduler: operation is not exist");
        require(block.timestamp % period >= delay, "Scheduler: error period");
        require(
            predecessor == bytes32(0) || !queuedOperations[predecessor],
            "Scheduler: missing dependency"
        );
    }

    function _call(
        bytes32 id,
        address target,
        uint256 value,
        string memory signature,
        bytes calldata data
    ) private {
        bytes memory callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        (bool success, ) = target.call{value: value}(callData);
        require(success, "Scheduler: underlying transaction reverted");
        emit CallExecuted(id);
    }

    function _afterCall(bytes32 id) private {
        queuedOperations[id] = false;
    }
}
