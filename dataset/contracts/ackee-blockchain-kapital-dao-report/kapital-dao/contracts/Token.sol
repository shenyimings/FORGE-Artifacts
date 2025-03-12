// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title Kapital DAO Token
 * @author Playground Labs
 * @custom:security-contact security@playgroundlabs.io
 * @notice 1 billion KAP tokens (plus 18 zeros) are minted in the constructor.
 * The total KAP supply cannot increase. However, the total KAP supply can
 * decrease via {burn}.
 */
contract Token is ERC20Burnable {
    constructor() ERC20("Kapital DAO Token", "KAP") {
        uint256 uiKapTotalSupply = 1e9;
        _mint(msg.sender, uiKapTotalSupply * (10**decimals()));
    }
}
