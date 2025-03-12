// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./DelegateCallGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract AdminControlled is DelegateCallGuard, AccessControlUpgradeable {
    address public admin;
    uint256 public paused;

    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    event OwnershipTransferred(address oldAdmin, address newAdmin);

    modifier pausable(uint256 flag) {
        require(
            (paused & flag) == 0 || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Paused"
        );
        _;
    }

    function __AdminControlled_init(uint256 _flags) public initializer {
        __AccessControl_init();
        paused = _flags;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSE_ROLE, msg.sender);
    }

    function adminPause(uint256 flags) external onlyRole(PAUSE_ROLE) {
        paused = flags;
    }

    function transferOwnership(address newAdmin)
        external
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newAdmin != address(0), "INVALID_ADDRESS");
        require(admin != newAdmin, "SAME_ADMIN_ADDRESS");
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        // This admin is used for colleting dust tokens,
        // and releasing some locked funds. It is used
        // by the staking contract. It must be assinged to
        // the community treasury wallet that will be governed
        // by DAO.
        admin = newAdmin;
        _revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
        emit OwnershipTransferred(_msgSender(), newAdmin);
    }

    function adminSstore(uint256 key, uint256 value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        assembly {
            sstore(key, value)
        }
    }

    function adminSstoreWithMask(
        uint256 key,
        uint256 value,
        uint256 mask
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        assembly {
            let oldval := sload(key)
            sstore(key, xor(and(xor(value, oldval), mask), oldval))
        }
    }

    function adminSendEth(address payable destination, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        //slither-disable-next-line arbitrary-send
        destination.transfer(amount);
    }

    function adminReceiveEth() external payable {}

    /// @custom:oz-upgrades-unsafe-allow delegatecall
    function adminDelegatecall(address target, bytes memory data)
        external
        payable
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyDelegateCall
        returns (bytes memory)
    {
        (bool success, bytes memory rdata) = target.delegatecall(data);
        require(success);
        return rdata;
    }
}
