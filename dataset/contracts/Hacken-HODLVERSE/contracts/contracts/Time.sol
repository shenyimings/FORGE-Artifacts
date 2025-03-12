// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract Time {
    using SafeMath for uint256;

    event NewOwner(address indexed newOwner);
    event NewPendingOwner(address indexed newPendingOwner);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    address public owner;
    address public pendingOwner;
    uint256 public delay;
    bool public owner_initialized;

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(address owner_, uint256 delay_) public {
        require(
            delay_ >= MINIMUM_DELAY,
            "Time::constructor: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "Time::constructor: Delay must not exceed maximum delay."
        );

        owner = owner_;
        delay = delay_;
    }

    receive() external payable {}

    function setDelay(uint256 delay_) public {
        require(
            msg.sender == address(this),
            "Time::setDelay: Call must come from Time."
        );
        require(
            delay_ >= MINIMUM_DELAY,
            "Time::setDelay: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "Time::setDelay: Delay must not exceed maximum delay."
        );
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptOwner() public {
        require(
            msg.sender == pendingOwner,
            "Time::acceptOwner: Call must come from pendingOwner."
        );
        owner = msg.sender;
        pendingOwner = address(0);

        emit NewOwner(owner);
    }

    function setPendingOwner(address pendingOwner_) public {
        // allows one time setting of owner for deployment purposes
        if (owner_initialized) {
            require(
                msg.sender == address(this),
                "Time::setPendingOwner: Call must come from Time."
            );
        } else {
            require(
                msg.sender == owner,
                "Time::setPendingOwner: First call must come from owner."
            );
            owner_initialized = true;
        }
        pendingOwner = pendingOwner_;

        emit NewPendingOwner(pendingOwner);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes32) {
        require(
            msg.sender == owner,
            "Time::queueTransaction: Call must come from owner."
        );
        require(
            eta >= getBlockTimestamp().add(delay),
            "Time::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public {
        require(
            msg.sender == owner,
            "Time::cancelTransaction: Call must come from owner."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable returns (bytes memory) {
        require(
            msg.sender == owner,
            "Time::executeTransaction: Call must come from owner."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        require(
            queuedTransactions[txHash],
            "Time::executeTransaction: Transaction hasn't been queued."
        );
        require(
            getBlockTimestamp() >= eta,
            "Time::executeTransaction: Transaction hasn't surpassed time lock."
        );
        require(
            getBlockTimestamp() <= eta.add(GRACE_PERIOD),
            "Time::executeTransaction: Transaction is stale."
        );

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        require(
            success,
            "Time::executeTransaction: Transaction execution reverted."
        );

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
