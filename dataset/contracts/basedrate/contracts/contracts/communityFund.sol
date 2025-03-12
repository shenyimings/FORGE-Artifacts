// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract CommunityFund is AccessControl {
    using Address for address payable;
    using SafeERC20 for IERC20;

    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(CALLER_ROLE, _msgSender());
    }

    function recoverBnb() external onlyRole(CALLER_ROLE) {
        payable(_msgSender()).sendValue(address(this).balance);
    }

    function recoverTokens(
        address tokenAddress,
        address to
    ) external onlyRole(CALLER_ROLE) {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    receive() external payable {}
}
