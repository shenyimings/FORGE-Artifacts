// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.26;

import "./ERC20.sol";

contract Treasury {
    ERC20 immutable _erc20;
    uint256 _firnSupply;
    uint256 constant _startGas = 10000000; // prevent low-gas attack (only get top elements)
    uint256 constant _endGas = 100000; // hardcode to save sloads...

    event Payout(address indexed recipient, uint256 amount);

    constructor(address erc20_) {
        _erc20 = ERC20(erc20_);
    }

    receive() external payable {

    }

    function payout() external {
        require(gasleft() >= _startGas, "Not enough gas supplied.");
        _firnSupply = _erc20.totalSupply();
        traverse(_erc20.root());
    }

    function traverse(address cursor) internal {
        (,address left,address right,) = _erc20.nodes(cursor);

        if (right != address(0)) {
            traverse(right);
        }
        if (gasleft() < _endGas) {
            return;
        }
        uint256 firnBalance = _erc20.balanceOf(cursor);
//        if (!_skip[cursor]) {
        uint256 amount = address(this).balance * firnBalance / _firnSupply;
        bool success = payable(cursor).send(amount);
        if (success) {
            emit Payout(cursor, amount);
        }
        // there is a further attack where someone could try to transfer their own firn balance within their `receive`.
        // the effect of this would be to get paid essentially twice for the same firn (there are other variants of this).
        // to prevent this, we're assuming that 2,300 gas isn't enough to do a FIRN ERC20 transfer.
        _firnSupply -= firnBalance;
        if (left != address(0)) {
            traverse(left);
        }
    }
}