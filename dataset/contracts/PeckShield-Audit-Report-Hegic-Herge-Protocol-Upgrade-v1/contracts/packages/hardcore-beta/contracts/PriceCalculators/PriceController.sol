pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2021 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ScaledPolynomialPriceCalculator.sol";
import "./PolynomialPriceCalculator.sol";

contract PriceController is AccessControl {
    bytes32 public constant PRICE_CORRECTOR_ROLE =
        keccak256("PRICE_CORRECTOR_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PRICE_CORRECTOR_ROLE, msg.sender);
    }

    function setDiscount(
        ScaledPolynomialPriceCalculator calculator,
        int256[5] calldata values
    ) external onlyRole(PRICE_CORRECTOR_ROLE) {
        calculator.setDiscount(values);
    }

    function setCoefficients(
        PolynomialPriceCalculator calculator,
        int256[5] calldata values
    ) external onlyRole(PRICE_CORRECTOR_ROLE) {
        calculator.setCoefficients(values);
    }

    function transferOwnership(Ownable calculator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        calculator.transferOwnership(msg.sender);
    }
}
