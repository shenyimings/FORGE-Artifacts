import "../interfaces/IStakePoolRewardRebaser.sol";
import "../libraries/SafeMath.sol";
contract StakePoolRewardRebaserMock is IStakePoolRewardRebaser {
    using SafeMath for uint;
    uint rate;
    constructor (uint _rate) public {
        rate = _rate;
    }
    function getRebaseAmount(address rewardToken, uint baseAmount) external override view returns (uint) {
        return baseAmount.mul(rate).div(1e18);
    }
}