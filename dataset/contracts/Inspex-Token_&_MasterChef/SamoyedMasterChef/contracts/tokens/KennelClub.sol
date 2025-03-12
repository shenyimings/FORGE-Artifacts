// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./BEP20.sol";
import "../tokens/SamoyToken.sol";

contract KennelClub is BEP20("KennelClub", "KENNEL"), ReentrancyGuard {
    using SafeMath for uint256;
    SamoyToken public smoy;

    constructor(SamoyToken _smoy) {
        smoy = _smoy;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) external onlyOwner nonReentrant {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyOwner nonReentrant {
        _burn(_from, _amount);
    }

    // Safe smoy transfer function, just in case if rounding error causes pool to not have enough KennelClubs.
    function safeSmoyTransfer(address _to, uint256 _amount) external onlyOwner nonReentrant {
        uint256 smoyBal = smoy.balanceOf(address(this));
        if (_amount > smoyBal) {
            smoy.transfer(_to, smoyBal);
        } else {
            smoy.transfer(_to, _amount);
        }
    }
}
