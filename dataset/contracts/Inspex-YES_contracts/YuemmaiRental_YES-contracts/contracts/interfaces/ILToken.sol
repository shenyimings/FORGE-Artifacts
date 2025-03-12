//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

import "../modules/kap20/interfaces/IKAP20.sol";

interface ILToken is IKAP20 {

    function mint(address account, uint amount) external;
    function burn(address account, uint amount) external;
    
}