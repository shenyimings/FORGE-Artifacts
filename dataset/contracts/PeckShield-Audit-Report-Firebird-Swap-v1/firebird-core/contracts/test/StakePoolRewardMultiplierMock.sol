import "../interfaces/IStakePoolRewardMultiplier.sol";
import "../libraries/SafeMath.sol";
contract StakePoolRewardMultiplierMock is IStakePoolRewardMultiplier {
    using SafeMath for uint;
    uint rate;
    constructor (uint _rate) public {
        rate = _rate;
    }
    function getRewardMultiplier(uint _start, uint _end, uint _from, uint _to, uint _rewardPerBlock) external override view returns (uint) {
        return _to.sub(_from).mul(_rewardPerBlock) .mul(rate).div(1e18);
    }
}