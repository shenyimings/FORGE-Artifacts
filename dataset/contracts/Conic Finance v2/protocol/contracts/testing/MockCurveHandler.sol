// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../contracts/CurveHandler.sol";

contract MockCurveHandler is CurveHandler {
    using SafeERC20 for IERC20;

    constructor(address controller_) CurveHandler(controller_) {}

    /// @dev used for testing
    function depositNoDelegateCall(address _curvePool, address _token, uint256 _amount) external {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        deposit(_curvePool, _token, _amount);
        address lpToken = controller.curveRegistryCache().lpToken(_curvePool);
        uint256 balance = IERC20(lpToken).balanceOf(address(this));
        IERC20(lpToken).safeTransfer(msg.sender, balance);
    }

    /// @dev used for testing when not calling using delegate call
    receive() external payable {}
}
