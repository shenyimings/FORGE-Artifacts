// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
 * Duelist King Token
 * Name: DAO Token
 * Domain: Duelist King
 */
contract DuelistKingToken is ERC20 {
  // For now, DKT is just an ordinary ERC20 token
  constructor(address genesis) ERC20('Duelist King Token', 'DKT') {
    // There are only 10,000,000 DKT
    _mint(genesis, 10000000 * (10**decimals()));
  }
}
