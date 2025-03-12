// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '../libraries/math/WadRayMath.sol';
import '../interfaces/IOpenSkyMoneymarket.sol';

interface ICEther {
    function balanceOf(address owner) external view returns (uint256);

    function mint() external payable;

    function mint(address to) external payable;

    function redeemUnderlying(uint256 amount) external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);
}

contract CompoundMoneyMarketMock is IOpenSkyMoneymarket {
    using SafeMath for uint256;
    using WadRayMath for uint256;
    address private immutable original;

    uint256 constant blocksPerYear = 2102400; // same as compound

    ICEther public immutable compoundCEther;

    constructor(ICEther compoundCEther_) public {
        compoundCEther = compoundCEther_;
        original = address(this);
    }

    function _requireDelegateCall() private view {
        require(address(this) != original);
    }

    modifier requireDelegateCall() {
        _requireDelegateCall();
        _;
    }

    function depositCall(uint256 amount) external payable override requireDelegateCall {
        compoundCEther.mint{value: amount}();
    }

    function withdrawCall(uint256 amount) external override requireDelegateCall {
        compoundCEther.redeemUnderlying(amount);
    }

    function simulateInterestIncrease(address to) external payable {
        compoundCEther.mint{value: msg.value}(to);
    }

    // supplyBalance(balanceOfUnderlying)
    function getBalance(address account) public view override returns (uint256) {
        uint256 exchangeRateStored = compoundCEther.exchangeRateStored();
        uint256 balanceOfoToken = compoundCEther.balanceOf(account);

        uint256 result = exchangeRateStored.mul(balanceOfoToken) / 1e18;
        return result;
    }

    // return ray
    function getSupplyRate() external view override returns (uint256) {
        return compoundCEther.supplyRatePerBlock().mul(blocksPerYear).wadToRay();
    }
}
