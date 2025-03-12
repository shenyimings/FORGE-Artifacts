// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ZNSFixedPricer } from "../../price/ZNSFixedPricer.sol";
import { UpgradeMock } from "../UpgradeMock.sol";


// solhint-disable-next-line no-empty-blocks
contract ZNSFixedPricerUpgradeMock is ZNSFixedPricer, UpgradeMock {}
