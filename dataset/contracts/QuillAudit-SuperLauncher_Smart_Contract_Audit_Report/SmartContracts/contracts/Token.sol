// SPDX-License-Identifier: agpl-3.0

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract SuperLauncherToken is
    ERC20,
    ERC20Burnable,
    Ownable
{
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    /**
     * @dev - The max supply.
     */
    uint256 internal constant INITIAL_SUPPLY = 4_000_000e18;
    uint256 internal constant LOCKED_SUPPLY = 2_000_000e18;
    uint256 public constant TOTAL_MAX_SUPPLY = 12_000_000e18;
    
    

    /**
     * @dev - The team release schedules
     */
     uint256[4]  public  teamAllocationLocks = [0 days, 30 days, 150 days, 270 days];
     uint256[4]  public teamReleaseAmount = [50_000e18, 500_000e18, 700_000e18, 750_000e18];
     bool[4] public teamReleased = [false, false, false, false];
     uint256 public immutable lockStartTime;

    constructor()
        public
        ERC20("Super Launcher", "LAUNCH")
    {
        _mint(msg.sender, INITIAL_SUPPLY);
        _mint(address(this), LOCKED_SUPPLY);
        lockStartTime = now;
    }

    /**
     * @dev - Mint token
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(ERC20.totalSupply().add(_amount) <= TOTAL_MAX_SUPPLY, "Max exceeded");
        _mint(_to, _amount);
    }

    /**
     * @dev - Team allocation - lock and release
     */
    function unlockTeamAllocation(uint256 _index) public onlyOwner {

        require(_index < 4, "Index out of range");
        require(teamReleased[_index]==false, "This allocation has been released previously");
       
        uint256 duration = teamAllocationLocks[_index];
        require(now >= lockStartTime.add(duration), "Still in time-lock");


        teamReleased[_index] = true;

        // transfer to owner address //
        ERC20 ercToken = ERC20(address(this));
        ercToken.safeTransfer(msg.sender, teamReleaseAmount[_index]);
    }

    function getTeamAllocationUnlockDate(uint256 _index) public view returns (uint256) {

        require(_index < 4, "Index out of range");
        return lockStartTime.add(teamAllocationLocks[_index]);
    }
}
