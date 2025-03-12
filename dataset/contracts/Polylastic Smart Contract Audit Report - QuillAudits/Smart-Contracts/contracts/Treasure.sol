// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Treasure is AccessControl {
    using SafeERC20 for IERC20;

    event WithdrawTax(address indexLP, uint256 amount, address to);

    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");

    constructor(address DAOAddress) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DAO_ADMIN_ROLE, DAOAddress);
    }

    function withdrawTax(
        address indexLP,
        uint256 amount,
        address to
    ) external onlyRole(DAO_ADMIN_ROLE) {
        IERC20(indexLP).safeTransfer(to, amount);
        emit WithdrawTax(indexLP, amount, to);
    }

    function balanceOf(address indexLP)
        external
        view
        returns (uint256 balance)
    {
        return (IERC20(indexLP).balanceOf(address(this)));
    }
}
