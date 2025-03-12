// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract TokenPool is AccessControlEnumerable, IERC1363Receiver {
    using SafeERC20 for IERC20;
    using Address for address;

    /**
     * Global Variables
     */

    string public constant VERSION = "v1.0.0";

    /**
     * Events
     */

    event PoolTransfer(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    event PoolApproval(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /**
     * Errors
     */

    error ErrForbidden();

    /**
     * Constructor
     */

    constructor(address newAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
    }

    /**
     * External/Public Functions
     */

    function transfer(
        address token,
        address to,
        uint256 amount
    ) external {
        // only admin
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert ErrForbidden();
        }

        emit PoolTransfer(token, to, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    function approve(
        address token,
        address to,
        uint256 amount
    ) external {
        // only admin
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert ErrForbidden();
        }

        emit PoolApproval(token, to, amount);
        IERC20(token).safeApprove(to, amount);
    }

    /**
     * Misc
     */

    // implementation of IERC1363Receiver
    function onTransferReceived(
        address,
        address,
        uint256,
        bytes calldata
    ) external view override returns (bytes4) {
        return IERC1363Receiver(this).onTransferReceived.selector;
    }
}
