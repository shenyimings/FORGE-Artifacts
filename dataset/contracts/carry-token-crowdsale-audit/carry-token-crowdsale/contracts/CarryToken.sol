// The Carry token and the tokensale contracts
// Copyright (C) 2018 Carry Protocol
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/CappedToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";

contract CarryToken is PausableToken, CappedToken, BurnableToken {
    string public name = "CarryToken";
    string public symbol = "CRE";
    uint8 public decimals = 18;

    // See also <https://carryprotocol.io/#section-token-distribution>.
    //                10 billion <---------|   |-----------------> 10^18
    uint256 constant TOTAL_CAP = 10000000000 * (10 ** uint256(decimals));

    constructor() public CappedToken(TOTAL_CAP) {
    }
}
