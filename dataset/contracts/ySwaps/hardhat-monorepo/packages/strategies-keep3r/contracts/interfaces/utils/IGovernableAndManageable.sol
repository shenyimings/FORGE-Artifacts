// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '@yearn-mechanics/contract-utils/solidity/contracts/utils/Governable.sol';
import '@yearn-mechanics/contract-utils/solidity/contracts/utils/Manageable.sol';

interface IGovernableAndManageable is IManageable, IGovernable {}
