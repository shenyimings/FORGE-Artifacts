// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./StakingRewardsLock.sol";
import "../interface/IOracle.sol";
import "../lib/SafeDecimalMath.sol";
import "../interface/ILiquidate.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interface/IPause.sol";

contract SatellitePool is StakingRewardsLock, ILiquidate, Pausable, IPause{
    using SafeDecimalMath for uint;

    address public liquidation;
    IOracle public oracle;
    bytes32 public stakingTokenSymbol;
    address public owner;
    uint256 public diffDecimal;

    constructor(
        address _liquidation,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken,
        address _oracle,
        bytes32 _sts,
        uint256 _lockDuration,
        uint256 _unlockPercent,
        uint256 _lockPercent,
        address _owner,
        uint256 _diffDecimal
    ) public 
        StakingRewardsLock(_rewardsDistribution, _rewardsToken, _stakingToken, _lockDuration, _unlockPercent, _lockPercent)
    {
        liquidation = _liquidation;
        oracle = IOracle(_oracle);
        stakingTokenSymbol = _sts;
        owner = _owner;
        diffDecimal = _diffDecimal;
    }

    function liquidate(address account) public override onlyLiquidation {
        stakingToken.safeTransfer(account, stakingToken.balanceOf(address(this)));
    }

    function tvl() public view returns(uint){
        uint tokenAmount = stakingToken.balanceOf(address(this));
        uint price = oracle.getPrice(stakingTokenSymbol);
        return tokenAmount.mul(10**(diffDecimal)).multiplyDecimal(price);
    }
    
    function withdraw(uint amount) public override whenNotPaused{
        super.withdraw(amount);
    } 

    function pause() public override onlyLiquidation {
        _pause();
    }

    function unpause() public override onlyLiquidation {
        _unpause();
    }

    function setLiquidation(address liqui) public onlyOwner {
        liquidation = liqui;
    }

    modifier onlyLiquidation {
        require(msg.sender == liquidation, "caller is not liquidator");
        _;
    }

     modifier onlyOwner() {
        require(owner == msg.sender, "SatellitePool: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        owner = newOwner;
    }
}
