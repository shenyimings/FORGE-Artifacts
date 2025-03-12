// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interface/FeeManager.sol";

contract InfiniteeFeeManager is FeeManager, Ownable {
    IERC20 public inftee;

    address public _feeAddress;
    uint256 public feeRate;
    uint256 public govFeeRate;
    uint256 public minGov;

    constructor(
        IERC20 _inftee,
        address _targetFeeAddress,
        uint256 _feeRate,
        uint256 _govFeeRate,
        uint256 _minGov
    ) public {
        inftee = _inftee;
        _feeAddress = _targetFeeAddress;
        feeRate = _feeRate;
        govFeeRate = _govFeeRate;
        minGov = _minGov;
    }

    function feeAddress() external view override returns (address) {
        return _feeAddress;
    }
    
    function feeRateBPS(
        address _user,
        uint256,
        uint256
    ) external view override returns (uint256) {
        uint256 _govAmount = inftee.balanceOf(_user);
        return _govAmount >= minGov ? govFeeRate : feeRate;
    }

    function setFeeRateWithGovAmount(uint256 _newFeeRate, uint256 _minGov)
        external
        onlyOwner
    {
        require(_newFeeRate < 1000, "fee: fee must not higher than 10%");
        govFeeRate = _newFeeRate;
        minGov = _minGov;
    }

    function setFeeRate(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate < 1000, "fee: fee must not higher than 10%");
        feeRate = _newFeeRate;
    }
}
