pragma solidity ^0.8.0;

import "./interfaces/IERC20Lite.sol";

/**
 * @title    DepositToken contract
 * @notice   Creates a contract with a known address and withdraws tokens from it.
 *           After deployment, the Vault will call fetch() to withdraw tokens.
 * @dev      The logic is not refactored into a single function because it's cheaper.
 */
contract Deposit {
    address payable private immutable vault;

    constructor(IERC20Lite token) {
        vault = payable(msg.sender);
        if (address(token) == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = msg.sender.call{value: address(this).balance}("");
            require(success);
        } else {
            // Not checking the return value to avoid reverts for tokens with no return value.
            token.transfer(msg.sender, token.balanceOf(address(this)));
        }
    }

    function fetch(IERC20Lite token) external {
        require(msg.sender == vault);

        // Slightly cheaper to use msg.sender instead of Vault.
        if (address(token) == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = msg.sender.call{value: address(this).balance}("");
            require(success);
        } else {
            // Not checking the return value to avoid reverts for tokens with no return value.
            token.transfer(msg.sender, token.balanceOf(address(this)));
        }
    }

    receive() external payable {}
}
