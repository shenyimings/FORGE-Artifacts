pragma solidity 0.4.25;

import "./Gold/Gold.sol";
import "./Common/Upgradable.sol";
import "./Common/SafeMath256.sol";


contract Treasury is Upgradable {
    using SafeMath256 for uint256;

    Gold goldTokens;

    uint256 constant GOLD_DECIMALS = 10 ** 18;
    uint256 constant public hatchingPrice = 1000 * GOLD_DECIMALS;

    function giveGold(address _user, uint256 _amount) external onlyController {
        goldTokens.transfer(_user, _amount);
    }

    function takeGold(uint256 _amount) external onlyController {
        goldTokens.remoteTransfer(this, _amount);
    }

    function burnGold(uint256 _amount) external onlyController {
        goldTokens.burn(_amount);
    }

    function remainingGold() external view returns (uint256) {
        return goldTokens.balanceOf(this);
    }

    // UPDATE CONTRACT
    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        goldTokens = Gold(_newDependencies[0]);
    }

    function migrate(address _newAddress) public onlyOwner {
        goldTokens.transfer(_newAddress, goldTokens.balanceOf(this));
    }
}
