// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// MilkyToken with Governance.
contract MilkyToken is ERC20("MilkyToken", "MILKY"), Ownable {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterMilker).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}