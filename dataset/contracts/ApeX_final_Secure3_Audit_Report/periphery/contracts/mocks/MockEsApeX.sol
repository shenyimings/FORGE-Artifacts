// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../staking/EsAPEX.sol";

contract MockEsApeX is EsAPEX {
    constructor() EsAPEX() {}

    function setFactory(address f) external {
        _addOperator(f);
    }
}
