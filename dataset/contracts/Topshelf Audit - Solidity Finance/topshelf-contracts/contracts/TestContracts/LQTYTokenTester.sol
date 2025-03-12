// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../LQTY/LIQRToken.sol";

contract LQTYTokenTester is LIQRToken {
    constructor
    (
        uint256 _supply,
        uint256 _maxSupply
    )
        public
        LIQRToken
    (
        address(0),
        _supply,
        _maxSupply
    )
    {}

    function unprotectedMint(address account, uint256 amount) external {
        // No check for the caller here

        _mint(account, amount);
    }

    function callInternalApprove(address owner, address spender, uint256 amount) external returns (bool) {
        _approve(owner, spender, amount);
    }

    function callInternalTransfer(address sender, address recipient, uint256 amount) external returns (bool) {
        _transfer(sender, recipient, amount);
    }

    function getChainId() external pure returns (uint256 chainID) {
        //return _chainID(); // itâ€™s private
        assembly {
            chainID := chainid()
        }
    }
}
