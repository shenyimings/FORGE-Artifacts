// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// $ROWA is the sole token of ROWA Platform, with a total supply of 1,000,000,000. 2% initial unlock. For Value Generation Pool, token amount is 360.000.000 and the lock-up period is 2% initial unlock. Monthly linear vesting over 50 months. For LP & Staking Rewards, token amount is 130.000.000 and the lock-up period is 2.77% initial unlock, Monthly linear vesting over 36 months. For Public Sale, token amount is 70.000.000 and the lock-up period is 25% initial unlock, Monthly linear vesting over 4 months. For Private Sale, token amount is 40.000.000 and the lock-up period is 5% initial unlock, cliff for 4 months, Monthly linear vesting over 12 months. For Seed Sale, token amount is 30.000.000 and the lock-up period is 5% initial unlock, cliff for 4 months, Monthly linear vesting over 12 months. For Initial Liquidity, token amount is 30.000.000 and the lock-up period is 100% initial unlock. For Reserve, token amount is 50.000.000 and the lock-up period is 20% initial unlock, 5 months vesting, unlocked every month. For Team, token amount is 150.000.000 and the lock-up period is 36 months vesting, unlocked every month starting from the 12th month. For Advisors, token amount is 40.000.000 and the lock-up period is 16 months vesting, unlocked every month starting from the 12th month. For Partnerships & Marketing, token amount is 100.000.000 and the lock-up period is 20% initial unlock, 5 months vesting, unlocked every month.

contract RowaToken is
    ERC20,
    ERC20Snapshot,
    ERC20Burnable,
    ERC20Pausable,
    Ownable
{
    using SafeMath for uint256;

    address public vestingContract;

    event TokenTransfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    // Token Information
    string public constant NAME = "ROWA Token";
    string public constant SYMBOL = "ROWA";
    uint8 public constant DECIMALS = 5;
    uint256 public constant INITIAL_SUPPLY =
        1_000_000_000 * 10 ** uint256(DECIMALS);

    // start time
    uint256 public startTime;

    constructor() ERC20(NAME, SYMBOL) {
        _mint(msg.sender, INITIAL_SUPPLY);
        _pause();
    }

    function startVesting(address _vestingContract) external onlyOwner {
        require(
            _vestingContract != address(0),
            "ROWAToken: vesting contract is the zero address"
        );
        require(startTime == 0, "ROWAToken: vesting already started");
        vestingContract = _vestingContract;

        startTime = block.timestamp;
        _unpause();

        // transfer to vesting contract
        _transfer(msg.sender, vestingContract, INITIAL_SUPPLY);
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot, ERC20Pausable) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // minting
            require(
                totalSupply().add(amount) <= INITIAL_SUPPLY,
                "ROWAToken: total supply exceeded"
            );
        }
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
