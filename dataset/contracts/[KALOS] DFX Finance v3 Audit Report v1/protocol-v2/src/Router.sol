// SPDX-License-Identifier: MIT

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.13;

import "./CurveFactoryV2.sol";
import "./Curve.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/ICurveFactory.sol";
import "./interfaces/IWeth.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// Simplistic router that assumes USD is the only quote currency for
contract Router {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public factory;
    address private immutable _wETH;

    constructor(address _factory) {
        require(_factory != address(0), "Curve/factory-cannot-be-zero-address");
        factory = _factory;
        _wETH = ICurveFactory(factory).wETH();
    }

    /// @notice view how much target amount a fixed origin amount will swap for
    /// @param _path the path to swap from origin to target
    /// @param _originAmount the origin amount
    /// @return targetAmount_ the amount of target that will be returned
    function viewOriginSwap(
        address[] memory _path,
        uint256 _originAmount
    ) external view returns (uint256 targetAmount_) {
        uint256 pathLen = _path.length;
        for (uint i = 0; i < pathLen - 1; ++i) {
            address payable curve = CurveFactoryV2(factory).getCurve(
                _path[i],
                _path[i + 1]
            );
            if (i == 0)
                targetAmount_ = Curve(curve).viewOriginSwap(
                    _path[i],
                    _path[i + 1],
                    _originAmount
                );
            else
                targetAmount_ = Curve(curve).viewOriginSwap(
                    _path[i],
                    _path[i + 1],
                    targetAmount_
                );
        }
    }

    function originSwap(
        uint256 _originAmount,
        uint256 _minTargetAmount,
        address[] memory _path,
        uint256 _deadline
    ) public returns (uint256 targetAmount_) {
        uint256 pathLen = _path.length;
        address origin = _path[0];
        address target = _path[pathLen - 1];
        IERC20(origin).safeTransferFrom(
            msg.sender,
            address(this),
            _originAmount
        );
        for (uint i = 0; i < pathLen - 1; ++i) {
            address payable curve = CurveFactoryV2(factory).getCurve(
                _path[i],
                _path[i + 1]
            );
            uint256 originBalance = IERC20(_path[i]).balanceOf(address(this));
            IERC20(_path[i]).safeApprove(curve, originBalance);
            targetAmount_ = Curve(curve).originSwap(
                _path[i],
                _path[i + 1],
                originBalance,
                0,
                _deadline
            );
        }
        require(targetAmount_ >= _minTargetAmount, "Router/originswap-failure");
        IERC20(target).safeTransfer(msg.sender, targetAmount_);
    }

    function originSwapFromETH(
        uint256 _minTargetAmount,
        address[] memory _path,
        uint256 _deadline
    ) public payable returns (uint256 targetAmount_) {
        // wrap ETH to WETH
        IWETH(_wETH).deposit{value: msg.value}();
        uint256 pathLen = _path.length;
        address origin = _path[0];
        require(origin == _wETH, "router/invalid-path");
        address target = _path[pathLen - 1];
        for (uint i = 0; i < pathLen - 1; ++i) {
            address payable curve = CurveFactoryV2(factory).getCurve(
                _path[i],
                _path[i + 1]
            );
            uint256 originBalance = IERC20(_path[i]).balanceOf(address(this));
            IERC20(_path[i]).safeApprove(curve, originBalance);
            targetAmount_ = Curve(curve).originSwap(
                _path[i],
                _path[i + 1],
                originBalance,
                0,
                _deadline
            );
        }
        require(
            targetAmount_ >= _minTargetAmount,
            "Router/originswap-from-ETH-failure"
        );
        IERC20(target).safeTransfer(msg.sender, targetAmount_);
    }

    function originSwapToETH(
        uint256 _originAmount,
        uint256 _minTargetAmount,
        address[] memory _path,
        uint256 _deadline
    ) public returns (uint256 targetAmount_) {
        uint256 pathLen = _path.length;
        address origin = _path[0];
        address target = _path[pathLen - 1];
        require(target == _wETH, "router/invalid-path");
        IERC20(origin).safeTransferFrom(
            msg.sender,
            address(this),
            _originAmount
        );
        for (uint i = 0; i < pathLen - 1; ++i) {
            address payable curve = CurveFactoryV2(factory).getCurve(
                _path[i],
                _path[i + 1]
            );
            uint256 originBalance = IERC20(_path[i]).balanceOf(address(this));
            IERC20(_path[i]).safeApprove(curve, originBalance);
            targetAmount_ = Curve(curve).originSwap(
                _path[i],
                _path[i + 1],
                originBalance,
                0,
                _deadline
            );
        }
        require(
            targetAmount_ >= _minTargetAmount,
            "Router/originswap-to-ETH-failure"
        );
        IWETH(_wETH).withdraw(targetAmount_);
        (bool success, ) = payable(msg.sender).call{value: targetAmount_}("");
        require(success, "router/eth-tranfer-failed");
    }

    /// @notice view how much of the origin currency the target currency will take
    /// @param _quoteCurrency the address of the quote currency (usually USDC)
    /// @param _origin the address of the origin
    /// @param _target the address of the target
    /// @param _targetAmount the target amount
    /// @return originAmount_ the amount of target that has been swapped for the origin
    function viewTargetSwap(
        address _quoteCurrency,
        address _origin,
        address _target,
        uint256 _targetAmount
    ) public view returns (uint256 originAmount_) {
        // If its an immediate pair then just swap directly on it
        address payable curve0 = CurveFactoryV2(factory).getCurve(
            _origin,
            _target
        );
        if (_origin == _quoteCurrency) {
            curve0 = CurveFactoryV2(factory).getCurve(_target, _origin);
        }

        if (curve0 != address(0)) {
            originAmount_ = Curve(curve0).viewTargetSwap(
                _origin,
                _target,
                _targetAmount
            );
            return originAmount_;
        }

        // Otherwise go through the quote currency
        curve0 = CurveFactoryV2(factory).getCurve(_target, _quoteCurrency);
        address payable curve1 = CurveFactoryV2(factory).getCurve(
            _origin,
            _quoteCurrency
        );
        if (curve0 != address(0) && curve1 != address(0)) {
            uint256 _quoteAmount = Curve(curve0).viewTargetSwap(
                _quoteCurrency,
                _target,
                _targetAmount
            );
            originAmount_ = Curve(curve1).viewTargetSwap(
                _origin,
                _quoteCurrency,
                _quoteAmount
            );
            return originAmount_;
        }

        revert("Router/No-path");
    }

    receive() external payable {}
}
