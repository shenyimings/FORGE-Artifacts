// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMetatimeToken.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../libs/Trigonometry.sol";

contract StrategicPool is Ownable2StepUpgradeable {
    using SafeMath for uint256;

    IMetatimeToken public token;
    int256 n = 0;
    int256 S = 1000;

    event Withdrew(uint256 amount);
    event Burned(uint256 amount, bool withFormula);

    constructor(IMetatimeToken _token) {
        _transferOwnership(_msgSender());

        token = _token;
    }

    function getTotalBurnedAmount() public view returns(int256) {
        return n;
    }

    function withdraw(uint256 withdrawalAmount) onlyOwner external {
        _transfer(owner(), withdrawalAmount);

        emit Withdrew(withdrawalAmount);
    }

    function burnWithFormula(int256 currentPrice, int256 blocksInTwoMonths) onlyOwner external {
        uint256 amount = uint256(calculateBurnAmount(currentPrice, blocksInTwoMonths));

        require(amount > 0, "burnWithFormula: Amount is too less!");

        token.burn(amount);

        n += int256(amount);

        emit Burned(1, true);
    }

    function burn(uint256 burnAmount) onlyOwner external {
        token.burn(burnAmount);

        n += int256(burnAmount);

        emit Burned(burnAmount, false);
    }

    function calculateBurnAmount(int256 _currentPrice, int256 _blocksInTwoMonths) public view returns(int256) {
        int256 LP = _currentPrice;
        int256 MB = _blocksInTwoMonths;

        int256 M = (((MB * 13 * 1e4 * 1e18) / ((100 * LP * 1e16) + (S * 1e18))) 
            * Trigonometry.cos(uint256((((86 * 1e18) + (n * 1e9)) * 3141592653589793238) / (180 * 1e18))) * 2923 * 1e15) / 1e18;

        return M;
    }

    function _transfer(address _to, uint256 _withdrawalAmount) internal returns(bool) {
        uint256 poolBalance = token.balanceOf(address(this));
        require(poolBalance > 0 && _withdrawalAmount <= poolBalance, "No tokens to withdraw!");

        require(token.transfer(_to, _withdrawalAmount), "Unable to transfer!");

        return true;
    }
}