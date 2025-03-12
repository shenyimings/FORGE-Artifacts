// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ================================ FPI ===============================
// ====================================================================
// Frax Price Index
// Initial peg target is the US CPI-U (Consumer Price Index, All Urban Consumers)

// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Travis Moore: https://github.com/FortisFortuna
// Jack Corddry: https://github.com/corddry

// Reviewer(s) / Contributor(s)
// Sam Kazemian: https://github.com/samkazemian
// Rich Gee: https://github.com/zer0blockchain
// Dennis: https://github.com/denett

import "../ERC20/ERC20PermissionedMint.sol";

contract FPI is ERC20PermissionedMint {

    /* ========== CONSTRUCTOR ========== */

    constructor(
      address _creator_address,
      address _timelock_address
    ) 
    ERC20PermissionedMint(_creator_address, _timelock_address, "Frax Price Index", "FPI") 
    {
      _mint(_creator_address, 100000000e18); // Genesis mint
    }

}