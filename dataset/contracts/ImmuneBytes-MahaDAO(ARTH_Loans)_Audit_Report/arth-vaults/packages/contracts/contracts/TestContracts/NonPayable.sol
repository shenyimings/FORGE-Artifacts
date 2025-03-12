// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

//import "../Dependencies/console.sol";
import "../Dependencies/IERC20.sol";

contract NonPayable {
    bool isPayable;

    IERC20 weth;

    constructor(IERC20 token) public {
        weth = token;
    }

    function setPayable(bool _isPayable) external {
        isPayable = _isPayable;
    }

    function forward(
        address _dest,
        bytes calldata _data,
        uint256 _amount
    ) external payable {
        weth.transferFrom(msg.sender, address(this), _amount);
        weth.approve(_dest, _amount);
        (bool success, bytes memory returnData) = _dest.call(_data);
        //console.logBytes(returnData);
        require(success, string(returnData));
    }

    receive() external payable {
        require(isPayable);
    }
}
