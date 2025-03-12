// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetatimeToken is ERC20, ERC20Burnable, Ownable {
    struct Pool {
        bytes32 name;
        address addr;
        uint256 lockedAmount;
    }

    event PoolSubmitted(bytes32 name, address addr, uint256 lockedAmount);
    
    // total supply: 10_000_000_000 * 10 ** decimals()
    constructor(Pool[] memory _pools, uint256 _totalSupply) ERC20("Metatime", "MTC") {
        _submitPools(_pools, _totalSupply);
    }

    function _submitPools(Pool[] memory _pools, uint256 _totalSupply) internal returns(bool) {
        uint256 usersLength = _pools.length;
        
        uint256 totalLockedAmount = 0;
        for (uint256 i = 0; i < usersLength; ) {
            Pool memory pool = _pools[i];
            _mint(pool.addr, pool.lockedAmount);
            emit PoolSubmitted(pool.name, pool.addr, pool.lockedAmount);
            unchecked {
                totalLockedAmount = totalLockedAmount + pool.lockedAmount;
                i += 1;
            }
        }

        require(_totalSupply >= totalLockedAmount, "Total claimable amount does not match");

        return true;
    }
}