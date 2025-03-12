//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

import "../modules/kap20/interfaces/IKAP20.sol";
import "../modules/kap20/interfaces/IKToken.sol";

interface IYESToken is IKAP20, IKToken {}