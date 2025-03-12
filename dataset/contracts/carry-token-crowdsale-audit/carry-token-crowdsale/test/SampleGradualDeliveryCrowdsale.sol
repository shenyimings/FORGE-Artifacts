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
pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/crowdsale/Crowdsale.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../contracts/GradualDeliveryCrowdsale.sol";

// Since GradualDeliveryCrowdsale is abstract and does not have its own
// constructor, we need to define a concrete class inheriting it and having
// its own constructor.
contract SampleGradualDeliveryCrowdsale is GradualDeliveryCrowdsale {
    constructor(
        uint256 _rate,
        address _wallet,
        ERC20 _token
    ) public Crowdsale(_rate, _wallet, _token) Ownable() {
    }
}
