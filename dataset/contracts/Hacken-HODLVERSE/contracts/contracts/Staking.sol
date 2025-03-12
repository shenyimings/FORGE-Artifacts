// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IReserve.sol";

// Staking is the coolest bar in town. You come in with some Money, and leave with more!
// The longer you stay, the more Money you get.
//This contract handles swapping to and from xMoney, HODL's staking token.
contract Staking is ERC20("Staking", "xMONEY"), Ownable {
    using SafeMath for uint256;
    IERC20 public money;
    IReserve public reserve;

    event SetReserveAddress(address _reserveAddress);
    event UpdatedReserveDistributionSchedule(
        uint256 _reserveDistributionSchedule
    );

    uint256 public reserveDistributionSchedule = 30 days;
    uint256 public lastReserveDistributionTimestamp;

    // Define the Money token contract
    constructor(address _money, address _reserve) public {
        require(
            _money != address(0),
            "Staking:constructor:: ERR_ZERO_ADDRESS_MONEY"
        );
        require(
            _reserve != address(0),
            "Staking:setReserveAddress:: ERR_ZERO_ADDRESS"
        );
        reserve = IReserve(_reserve);
        money = IERC20(_money);
    }

    function setReserveAddress(address _reserveAddress) external onlyOwner {
        require(
            _reserveAddress != address(0),
            "Staking:setReserveAddress:: ERR_ZERO_ADDRESS"
        );
        reserve = IReserve(_reserveAddress);
        emit SetReserveAddress(_reserveAddress);
    }

    // Enter the bar. Pay some MONEYs. Earn some shares.
    // Locks Money and mints xMoney
    function enter(uint256 _amount) external {
        // Gets the amount of Money locked in the contract
        uint256 totalMoney = money.balanceOf(address(this));
        // Gets the amount of xMoney in existence
        uint256 totalShares = totalSupply();
        // If no xMoney exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalMoney == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xMoney the Money is worth.
        // The ratio will change overtime, as xMoney is burned/minted and
        // Money deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalMoney);
            _mint(msg.sender, what);
        }
        // Lock the Money in the contract
        money.transferFrom(msg.sender, address(this), _amount);
    }

    function _canCollectRewards() internal view returns (bool) {
        if (
            lastReserveDistributionTimestamp.add(reserveDistributionSchedule) <=
            block.timestamp &&
            reserve.canWithdraw()
        ) return true;

        return false;
    }

    function accumulateRewards() public {
        require(
            _canCollectRewards(),
            "Staking:accumulateRewards:: ERR_CANNOT_COLLECT_REWARDS"
        );
        lastReserveDistributionTimestamp = block.timestamp;
        reserve.withdrawRewards();
    }

    // Leave the bar. Claim back your MONEYs.
    // Unlocks the staked + gained Money and burns xMoney
    function leave(uint256 _share) external {
        //fetch rewards if its time
        if (_canCollectRewards()) accumulateRewards();

        // Gets the amount of xMoney in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Money the xMoney is worth
        uint256 what = _share.mul(money.balanceOf(address(this))).div(
            totalShares
        );
        _burn(msg.sender, _share);
        money.transfer(msg.sender, what);
    }

    function updateReserveDistributionSchedule(
        uint256 _reserveDistributionSchedule
    ) external onlyOwner {
        reserveDistributionSchedule = _reserveDistributionSchedule;
        emit UpdatedReserveDistributionSchedule(_reserveDistributionSchedule);
    }
}
